data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = [var.ami_name_filter]
  }
}

locals {
  environment = var.environment
  env_suffix = local.environment == "production" ? "prod" : "nonprod"
  base_name   = var.name_prefix
}

data "aws_key_pair" "ssh" {
  key_name = var.ssh_keypair_name
}

resource "random_password" "main" {
  length  = 16
  special = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "main" {
  name = var.db_secret_name
  tags = {
    Environment = local.environment
  }
}

resource "aws_secretsmanager_secret_version" "main" {
  secret_id = aws_secretsmanager_secret.main.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.main.result
  })
}

resource "aws_secretsmanager_secret" "connection_string" {
  name = "${var.db_secret_name}-connection-string"
  tags = {
    Environment = local.environment
  }
}

resource "aws_secretsmanager_secret_version" "connection_string" {
  secret_id = aws_secretsmanager_secret.connection_string.id
  secret_string = "postgresql://${var.db_username}:${random_password.main.result}@${aws_db_instance.main.endpoint}/postgres"
  depends_on = [aws_db_instance.main]
}

resource "aws_iam_policy" "secretsmanager" {
  name = "${local.base_name}-iam-aws-${local.env_suffix}-secretsmanager-policy"
  policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": [
                    "secretsmanager:GetSecretValue"
                ],
                "Resource": [
                    "${aws_secretsmanager_secret.main.arn}",
                    "${aws_secretsmanager_secret.connection_string.arn}"
                ],
                "Effect": "Allow"
            }
        ]
    }
    EOF
  tags = {
    Environment = local.environment
  }
}

resource "aws_iam_role" "main" {
  name = "${local.base_name}-iam-aws-${local.env_suffix}-ec2-role"
  assume_role_policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Effect": "Allow",
                "Principal": {
                    "Service": "ec2.amazonaws.com"
                }
            }
        ]
    }
    EOF
  tags = {
    Environment = local.environment
  }
}

resource "aws_iam_instance_profile" "main" {
  name = aws_iam_role.main.name
  role = aws_iam_role.main.name
}

resource "aws_iam_role_policy_attachment" "secretsmanager" {
  role       = aws_iam_role.main.name
  policy_arn = aws_iam_policy.secretsmanager.arn
}

resource "aws_lb" "main" {
  name               = "${local.base_name}-alb-${local.env_suffix}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids
  tags = {
    Name        = "${local.base_name}-alb-${local.env_suffix}"
    Environment = local.environment
  }
}

resource "aws_lb_target_group" "main" {
  name     = "${local.base_name}-tg-${local.env_suffix}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.main.id
  health_check {
    path = "/"
  }
  tags = {
    Environment = local.environment
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_launch_template" "main" {
  name_prefix   = "${local.base_name}-lt-${local.env_suffix}-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = data.aws_key_pair.ssh.key_name
  user_data     = var.user_data_script

  vpc_security_group_ids = [var.app_sg_id]

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_type = "gp3"
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.main.name
  }

  tags = {
    Name        = "${local.base_name}-asg-instance-${local.env_suffix}"
    Environment = local.environment
  }
}

resource "aws_autoscaling_group" "main" {
  name                   = "${local.base_name}-asg-${local.env_suffix}"
  min_size               = var.min_size
  max_size               = var.max_size
  desired_capacity       = var.desired_capacity
  default_instance_warmup = 300
  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }
  vpc_zone_identifier = var.app_subnet_ids
  target_group_arns   = [aws_lb_target_group.main.arn]

  tag {
    key                 = "Name"
    value               = "${local.base_name}-asg-instance-${local.env_suffix}"
    propagate_at_launch = true
  }
  tag {
    key                 = "Environment"
    value               = local.environment
    propagate_at_launch = true
  }
  dynamic "tag" {
    for_each = var.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "${local.base_name}-cpu-target-tracking-${local.env_suffix}"
  autoscaling_group_name = aws_autoscaling_group.main.name
  policy_type           = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "${local.base_name}-db-subnet-group-${local.env_suffix}"
  subnet_ids = var.database_subnet_ids
  tags = {
    Name        = "${local.base_name}-db-subnet-group-${local.env_suffix}"
    Environment = local.environment
  }
}

resource "aws_db_instance" "main" {
  identifier             = "${local.base_name}-rds-${local.env_suffix}"
  engine                 = "postgres"
  engine_version         = var.db_engine_version
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  username               = var.db_username
  password               = jsondecode(aws_secretsmanager_secret_version.main.secret_string)["password"]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.database_sg_id]
  multi_az               = false
  skip_final_snapshot    = true

  tags = {
    Name        = "${local.base_name}-rds-${local.env_suffix}"
    Environment = local.environment
  }
}
