# ECS Task가 target group으로 등록되지 않는 문제 발생
# + terraform code 이름 수정

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.VPC_CIDR
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name        = "${var.APP_NAME}-vpc"
    Environment = var.APP_ENV
  }
}

resource "aws_internet_gateway" "aws-igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name        = "${var.APP_NAME}-igw"
    Environment = var.APP_ENV
  }
}

# EIP for NAT
resource "aws_eip" "nat-gw-ip" {
  count      = length(var.AZ)
  depends_on = [aws_internet_gateway.aws-igw]
}

resource "aws_nat_gateway" "aws-nat-gw" {
  count         = length(var.AZ)
  subnet_id     = element(aws_subnet.public.*.id, count.index)
  allocation_id = element(aws_eip.nat-gw-ip.*.id, count.index)
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(var.PUBLIC_CIDR, count.index)
  availability_zone       = element(var.AZ, count.index)
  count                   = length(var.PUBLIC_CIDR)
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.APP_NAME}-public-subnet-${count.index + 1}"
    Environment = var.APP_ENV
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  count             = length(var.PRIVATE_CIDR)
  cidr_block        = element(var.PRIVATE_CIDR, count.index)
  availability_zone = element(var.AZ, count.index)

  tags = {
    Name        = "${var.APP_NAME}-private-subnet-${count.index + 1}"
    Environment = var.APP_ENV
  }
}

resource "aws_subnet" "cache" {
  vpc_id            = aws_vpc.main.id
  count             = length(var.CACHE_CIDR)
  cidr_block        = element(var.CACHE_CIDR, count.index)
  availability_zone = element(var.AZ, count.index)

  tags = {
    Name        = "${var.APP_NAME}-cache-subnet-${count.index + 1}"
    Environment = var.APP_ENV
  }
}

resource "aws_elasticache_subnet_group" "cache-subnet-group" {
  name       = "cache-subnet-group"
  subnet_ids = flatten(tolist(aws_subnet.cache.*.id))
}

resource "aws_subnet" "db" {
  vpc_id            = aws_vpc.main.id
  count             = length(var.DB_CIDR)
  cidr_block        = element(var.DB_CIDR, count.index)
  availability_zone = element(var.AZ, count.index)

  tags = {
    Name        = "${var.APP_NAME}-db-subnet-${count.index + 1}"
    Environment = var.APP_ENV
  }
}

# public routing table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.APP_NAME}-routing-table-public"
    Environment = var.APP_ENV
  }
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.aws-igw.id
}

resource "aws_route_table_association" "public" {
  count          = length(var.PUBLIC_CIDR)
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

# private routing table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.APP_NAME}-routing-table-private"
    Environment = var.APP_ENV
  }
}

resource "aws_route" "private" {
  count = length(aws_nat_gateway.aws-nat-gw.*.id)
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = element(aws_nat_gateway.aws-nat-gw.*.id, count.index)
}

resource "aws_route_table_association" "private" {
  count          = length(var.PRIVATE_CIDR)
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

# DB SUBNET GROUP
resource "aws_db_subnet_group" "rds-subnet-group" {
  name       = "rds_subnet_group"
  subnet_ids = flatten(tolist(aws_subnet.db.*.id))

  tags = {
    Name        = "${var.APP_NAME}-db-subnet-group"
    Environment = var.APP_ENV
  }
}

# ALB SIDE
######################### INTERNET FACING ALB FOR CLOUDFRONT DISTRIBUTION #########################
resource "aws_alb" "main-alb" {
  name               = "${var.APP_NAME}-${var.SIDE[1]}-${var.APP_ENV}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.public.*.id
  security_groups    = [aws_security_group.main-alb-sg.id]

  tags = {
    Name        = "${var.APP_NAME}-${var.SIDE[1]}-alb"
    Environment = var.APP_ENV
  }
}

resource "aws_lb_target_group" "main-target-group" {
  name        = "${var.APP_NAME}-${var.SIDE[1]}-${var.APP_ENV}-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip" # for fargate type
  vpc_id      = aws_vpc.main.id

  health_check {
    healthy_threshold   = "3"
    interval            = "300"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = var.HEALTH_CHECK_PATH
    unhealthy_threshold = "2"
  }

  tags = {
    Name        = "${var.APP_NAME}-${var.SIDE[1]}-tg"
    Environment = var.APP_ENV
  }
}

resource "aws_lb_listener" "main-listener" {
  load_balancer_arn = aws_alb.main-alb.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main-target-group.id
  }
}

resource "aws_lb_listener_rule" "ecs_fargate_listener_rule" {
  listener_arn = aws_lb_listener.main-listener.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main-target-group.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }
}

resource "null_resource" "INTERNET-FACING-ALB-DOMAIN-TO-FRONTEND-DIRECTORY" {
  provisioner "local-exec" {
    # command = "echo \"ALB_DOMAIN=\${aws_alb.main-alb.dns_name}\" >> \${var.JENKINS_WORKSPACE_PATH}/frontend/.env"
    # 아래의 command = sudo 권한을 사용하기 때문에 terminal에서 비번 입력해 줘야함.
    # but jenkins 서버 설정에서는 sudo 권한 password 필요없음
    command = <<EOC
      echo "ALB_DOMAIN=$ALB_DNS_NAME" >> $JENKINS_WORKSPACE_PATH/frontend/.env
    EOC

    environment = {
      ALB_DNS_NAME           = aws_alb.main-alb.dns_name
      JENKINS_WORKSPACE_PATH = var.JENKINS_WORKSPACE_PATH
    }
  }
  depends_on = [aws_alb.main-alb]
}


######################### SECURITY GRUOP #########################

data "aws_ec2_managed_prefix_list" "cloudfront-prefix-list" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}
resource "aws_security_group" "main-alb-sg" { # should allow only cloudfront request
  vpc_id = aws_vpc.main.id
  name   = "main-alb-sg"

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront-prefix-list.id]
    // ap-northeast-2 cloudfront 접두사임.
    // 
    // https://dev.to/kaspersfranz/limit-traffic-to-only-cloudfront-traffic-in-aws-alb-3c6 참고
  }

  # for test under line ingress 
  ingress {
    protocol         = "tcp"
    from_port        = 80
    to_port          = 80
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.APP_NAME}-${var.SIDE[1]}-alb-sg"
    Environment = var.APP_ENV
  }
}

# ecs backend service sg
resource "aws_security_group" "backend-service-security-group" {
  vpc_id = aws_vpc.main.id
  name   = "backend-service-sg"

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.main-alb-sg.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "${var.APP_NAME}-${var.SIDE[1]}-service-sg"
    Environment = var.APP_ENV
  }
}
# CACHE SG(memcached)
resource "aws_security_group" "cache-security-group" {
  vpc_id = aws_vpc.main.id
  name   = "main-cache-sg"

  ingress {
    from_port       = var.CACHE_PORT
    to_port         = var.CACHE_PORT
    protocol        = "tcp"
    security_groups = [aws_security_group.backend-service-security-group.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "${var.APP_NAME}-cache-sg"
    Environment = var.APP_ENV
  }
}


# RDS SG(mysql)
resource "aws_security_group" "rds-security-group" {
  vpc_id = aws_vpc.main.id
  name = "main-mysql-sg"

  ingress {
    from_port       = var.DB_PORT
    to_port         = var.DB_PORT
    protocol        = "tcp"
    security_groups = [aws_security_group.backend-service-security-group.id, aws_security_group.cache-security-group.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "${var.APP_NAME}-rds-sg"
    Environment = var.APP_ENV
  }
}


# ######################### INTERNAL ALB FOR BACKEND SIDE #########################

# resource "aws_alb" "backend-alb" {
#   name               = "${var.APP_NAME}-${var.SIDE[1]}-${var.APP_ENV}-alb"
#   internal           = true
#   load_balancer_type = "application"
#   subnets            = aws_subnet.private.*.id
#   security_groups    = [aws_security_group.backend-alb-sg.id]

#   tags = {
#     Name        = "${var.APP_NAME}-${var.SIDE[1]}-alb"
#     Environment = var.APP_ENV
#   }
# }

# resource "aws_lb_target_group" "backend-target-group" {
#   name        = "${var.APP_NAME}-${var.APP_ENV}-tg"
#   port        = 80
#   protocol    = "HTTP"
#   target_type = "ip"
#   vpc_id      = aws_vpc.main.id

#   health_check {
#     healthy_threshold   = "3"
#     interval            = "300"
#     protocol            = "HTTP"
#     matcher             = "200"
#     timeout             = "3"
#     path                = "var.HEALTH_CHECK_PATH"
#     unhealthy_threshold = "2"
#   }

#   tags = {
#     Name        = "${var.APP_NAME}-${var.SIDE[1]}-lb-tg"
#     Environment = var.APP_ENV
#   }
# }

# resource "aws_lb_listener" "backend-listener" {
#   load_balancer_arn = aws_alb.backend-alb.id
#   port              = "80"
#   protocol          = "HTTP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.backend-target-group.id
#   }
# }