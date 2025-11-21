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
  source          = "hashicorp/subnets/cidr"

  base_cidr_block = var.vpc_cidr
  networks        = var.subnet_config
}

locals {
  environment = var.environment
  env_suffix  = local.environment == "production" ? "prod" : "nonprod"
  base_name   = var.name_prefix
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name        = var.vpc_name
    Environment = local.environment
  }
}

resource "aws_subnet" "public" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = module.subnet_addrs.network_cidr_blocks["public-${substr(var.azs[count.index], -1, 1)}"]
  availability_zone = var.azs[count.index]
  tags = {
    Name        = "${local.base_name}-public-${var.azs[count.index]}-${local.env_suffix}"
    Environment = local.environment
  }
}

resource "aws_subnet" "private_app" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = module.subnet_addrs.network_cidr_blocks["private-app-${substr(var.azs[count.index], -1, 1)}"]
  availability_zone = var.azs[count.index]
  tags =  {
    Name        = "${local.base_name}-private-app-${var.azs[count.index]}-${local.env_suffix}"
    Environment = local.environment
  }
}

resource "aws_subnet" "private_database" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = module.subnet_addrs.network_cidr_blocks["private-database-${substr(var.azs[count.index], -1, 1)}"]
  availability_zone = var.azs[count.index]
  tags = {
    Name        = "${local.base_name}-private-database-${var.azs[count.index]}-${local.env_suffix}"
    Environment = local.environment
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name        = "${local.base_name}-igw-${local.env_suffix}"
    Environment = local.environment
  }
}

resource "aws_eip" "nat" {
  count = length(var.azs)
  domain = "vpc"
  tags = {
    Name        = "${local.base_name}-nat-eip-${count.index + 1}-${local.env_suffix}"
    Environment = local.environment
  }
}

resource "aws_nat_gateway" "main" {
  count         = length(var.azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags = {
    Name        = "${local.base_name}-nat-gw-${count.index + 1}-${local.env_suffix}"
    Environment = local.environment
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
    Environment = local.environment
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_app" {
  count = length(var.azs)
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }
  tags = {
    Name        = "${local.base_name}-private-app-rt-${count.index + 1}-${local.env_suffix}"
    Environment = local.environment
  }
}

resource "aws_route_table_association" "private_app" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[count.index].id
}

resource "aws_route_table" "private_database" {
  count = length(var.azs)
  vpc_id = aws_vpc.main.id
  # No internet route - database subnets should not have outbound internet access
  tags = {
    Name        = "${local.base_name}-private-database-rt-${count.index + 1}-${local.env_suffix}"
    Environment = local.environment
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
    Environment = local.environment
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
    Environment = local.environment
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
    Environment = local.environment
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
    Environment = local.environment
  }
}

resource "aws_network_acl" "public" {
  vpc_id = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id

  ingress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

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
    Environment = local.environment
  }
}

resource "aws_network_acl" "private_app" {
  vpc_id = aws_vpc.main.id
  subnet_ids = aws_subnet.private_app[*].id

  ingress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name        = "${local.base_name}-private-app-nacl-${local.env_suffix}"
    Environment = local.environment
  }
}

resource "aws_network_acl" "private_database" {
  vpc_id = aws_vpc.main.id
  subnet_ids = aws_subnet.private_database[*].id

  ingress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name        = "${local.base_name}-private-database-nacl-${local.env_suffix}"
    Environment = local.environment
  }
}

resource "aws_instance" "bastion" {
  count                   = var.create_bastion ? 1 : 0
  ami                     = data.aws_ami.amazon_linux.id
  instance_type           = var.bastion_instance_type
  key_name                = aws_key_pair.ssh.key_name
  subnet_id               = aws_subnet.public[0].id
  vpc_security_group_ids  = [aws_security_group.bastion.id]
  associate_public_ip_address = true

  root_block_device {
    volume_type = "gp3"
  }

  tags = {
    Name        = "${local.base_name}-bastion-${local.env_suffix}"
    Environment = local.environment
  }
}
