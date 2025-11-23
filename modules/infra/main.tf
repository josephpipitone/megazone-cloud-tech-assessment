data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ssh" {
  key_name   = var.ssh_keypair_name
  public_key = tls_private_key.ssh.public_key_openssh
}

module "subnet_addrs" {
  source = "hashicorp/subnets/cidr"

  base_cidr_block = var.vpc_cidr
  networks        = var.subnet_config
}

locals {
  env_suffix            = var.environment == "production" ? "prod" : "nonprod"
  base_name             = var.name_prefix
  public_subnet_cidrs   = [for s in aws_subnet.public : s.cidr_block]
  app_subnet_cidrs      = [for s in aws_subnet.private_app : s.cidr_block]
  database_subnet_cidrs = [for s in aws_subnet.private_database : s.cidr_block]
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name        = var.vpc_name
  }
}

resource "aws_subnet" "public" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = module.subnet_addrs.network_cidr_blocks["public-${substr(var.azs[count.index], -1, 1)}"]
  availability_zone = var.azs[count.index]
  tags = {
    Name        = "${local.base_name}-public-${var.azs[count.index]}-${local.env_suffix}"
  }
}

resource "aws_subnet" "private_app" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = module.subnet_addrs.network_cidr_blocks["private-app-${substr(var.azs[count.index], -1, 1)}"]
  availability_zone = var.azs[count.index]
  tags = {
    Name        = "${local.base_name}-private-app-${var.azs[count.index]}-${local.env_suffix}"
  }
}

resource "aws_subnet" "private_database" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = module.subnet_addrs.network_cidr_blocks["private-database-${substr(var.azs[count.index], -1, 1)}"]
  availability_zone = var.azs[count.index]
  tags = {
    Name        = "${local.base_name}-private-database-${var.azs[count.index]}-${local.env_suffix}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name        = "${local.base_name}-igw-${local.env_suffix}"
  }
}

resource "aws_eip" "nat" {
  count  = length(var.azs)
  domain = "vpc"
  tags = {
    Name        = "${local.base_name}-nat-eip-${count.index + 1}-${local.env_suffix}"
  }
}

resource "aws_nat_gateway" "main" {
  count         = length(var.azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags = {
    Name        = "${local.base_name}-nat-gw-${count.index + 1}-${local.env_suffix}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name        = "${local.base_name}-public-rt-${local.env_suffix}"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_app" {
  count  = length(var.azs)
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }
  tags = {
    Name        = "${local.base_name}-private-app-rt-${count.index + 1}-${local.env_suffix}"
  }
}

resource "aws_route_table_association" "private_app" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[count.index].id
}

resource "aws_route_table" "private_database" {
  count  = length(var.azs)
  vpc_id = aws_vpc.main.id
  # No internet route - database subnets should not have outbound internet access
  tags = {
    Name        = "${local.base_name}-private-database-rt-${count.index + 1}-${local.env_suffix}"
  }
}

resource "aws_route_table_association" "private_database" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.private_database[count.index].id
  route_table_id = aws_route_table.private_database[count.index].id
}

resource "aws_security_group" "alb" {
  name_prefix = "alb-"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "${local.base_name}-alb-sg-${local.env_suffix}"
  }
}

resource "aws_security_group" "app" {
  name_prefix = "app-"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "${local.base_name}-app-sg-${local.env_suffix}"
  }
}

resource "aws_security_group" "database" {
  name_prefix = "database-"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "${local.base_name}-database-sg-${local.env_suffix}"
  }
}

resource "aws_security_group" "bastion" {
  name_prefix = "bastion-"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.bastion_allowed_ip]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "${local.base_name}-bastion-sg-${local.env_suffix}"
  }
}

resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id

  # Allow HTTP from internet (for ALB)
  ingress {
    rule_no    = 90
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  # Allow HTTPS from internet (for ALB)
  ingress {
    rule_no    = 95
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Allow HTTPS from app subnets only
  dynamic "ingress" {
    for_each = local.app_subnet_cidrs
    content {
      rule_no    = 100 + ingress.key * 20
      protocol   = "tcp"
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 443
      to_port    = 443
    }
  }

  # Allow SSH from bastion allowed IP
  ingress {
    rule_no    = 180
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.bastion_allowed_ip
    from_port  = 22
    to_port    = 22
  }

  # Allow all ports for traffic from app subnets (outbound and return)
  dynamic "ingress" {
    for_each = local.app_subnet_cidrs
    content {
      rule_no    = 200 + ingress.key * 20
      protocol   = "tcp"
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 0
      to_port    = 65535
    }
  }

  # Allow ephemeral ports for return traffic from internet
  ingress {
    rule_no    = 190
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Allow outbound to internet
  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name        = "${local.base_name}-public-nacl-${local.env_suffix}"
  }
}

resource "aws_network_acl" "private_app" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private_app[*].id

  # Allow HTTP from public subnets (ALB to EC2 instances)
  dynamic "ingress" {
    for_each = local.public_subnet_cidrs
    content {
      rule_no    = 80 + ingress.key * 5
      protocol   = "tcp"
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 80
      to_port    = 80
    }
  }

  # Allow return traffic from database subnets (ephemeral ports)
  dynamic "ingress" {
    for_each = local.database_subnet_cidrs
    content {
      rule_no    = 100 + ingress.key * 20
      protocol   = "tcp"
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 1024
      to_port    = 65535
    }
  }

  # Allow ephemeral ports for return traffic (NAT gateway responses)
  ingress {
    rule_no    = 180
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # Allow outbound ephemeral responses to public subnets (EC2 to ALB)
  dynamic "egress" {
    for_each = local.public_subnet_cidrs
    content {
      rule_no    = 180 + egress.key * 5
      protocol   = "tcp"
      action     = "allow"
      cidr_block = egress.value
      from_port  = 1024
      to_port    = 65535
    }
  }

  # Allow outbound to database subnets
  dynamic "egress" {
    for_each = local.database_subnet_cidrs
    content {
      rule_no    = 200 + egress.key * 20
      protocol   = "tcp"
      action     = "allow"
      cidr_block = egress.value
      from_port  = 5432
      to_port    = 5432
    }
  }

  # Allow outbound to public subnets (NAT gateway)
  dynamic "egress" {
    for_each = local.public_subnet_cidrs
    content {
      rule_no    = 280 + egress.key * 20
      protocol   = "-1"
      action     = "allow"
      cidr_block = egress.value
      from_port  = 0
      to_port    = 0
    }
  }

  # Allow outbound to internet (via NAT gateway)
  egress {
    rule_no    = 380
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name        = "${local.base_name}-private-app-nacl-${local.env_suffix}"
  }
}

resource "aws_network_acl" "private_database" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private_database[*].id

  # Allow PostgreSQL from app subnets
  dynamic "ingress" {
    for_each = local.app_subnet_cidrs
    content {
      rule_no    = 100 + ingress.key * 20
      protocol   = "tcp"
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 5432
      to_port    = 5432
    }
  }

  # Allow traffic from other database subnets
  dynamic "ingress" {
    for_each = local.database_subnet_cidrs
    content {
      rule_no    = 180 + ingress.key * 20
      protocol   = "-1"
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 0
      to_port    = 0
    }
  }

  # Allow ephemeral return traffic from app subnets
  dynamic "ingress" {
    for_each = local.app_subnet_cidrs
    content {
      rule_no    = 260 + ingress.key * 20
      protocol   = "tcp"
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 1024
      to_port    = 65535
    }
  }

  # Allow ephemeral return traffic to app subnets
  dynamic "egress" {
    for_each = local.app_subnet_cidrs
    content {
      rule_no    = 340 + egress.key * 20
      protocol   = "tcp"
      action     = "allow"
      cidr_block = egress.value
      from_port  = 1024
      to_port    = 65535
    }
  }

  # Allow outbound to other database subnets
  dynamic "egress" {
    for_each = local.database_subnet_cidrs
    content {
      rule_no    = 420 + egress.key * 20
      protocol   = "-1"
      action     = "allow"
      cidr_block = egress.value
      from_port  = 0
      to_port    = 0
    }
  }

  tags = {
    Name        = "${local.base_name}-private-database-nacl-${local.env_suffix}"
  }
}

resource "aws_instance" "bastion" {
  count                       = var.create_bastion ? 1 : 0
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.bastion_instance_type
  key_name                    = aws_key_pair.ssh.key_name
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true

  root_block_device {
    volume_type = "gp3"
  }

  tags = {
    Name        = "${local.base_name}-bastion-${local.env_suffix}"
  }
}

