
# ALB Security Group — allows inbound HTTP from the internet
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Allow HTTP inbound to ALB"
  vpc_id      = data.aws_vpc.default.id

  tags = { Name = "${local.name_prefix}-alb-sg" }
}

resource "aws_security_group_rule" "alb_ingress_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP from internet"
}

resource "aws_security_group_rule" "alb_egress_to_ecs" {
  type                     = "egress"
  from_port                = var.container_port
  to_port                  = var.container_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs.id
  security_group_id        = aws_security_group.alb.id
  description              = "Allow traffic to ECS tasks"
}

resource "aws_security_group" "ecs" {
  name        = "${local.name_prefix}-ecs-sg"
  description = "Allow inbound from ALB only"
  vpc_id      = data.aws_vpc.default.id

  tags = { Name = "${local.name_prefix}-ecs-sg" }
}

resource "aws_security_group_rule" "ecs_ingress_from_alb" {
  type                     = "ingress"
  from_port                = var.container_port
  to_port                  = var.container_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.ecs.id
  description              = "Allow traffic from ALB"
}

resource "aws_security_group_rule" "ecs_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs.id
  description       = "Allow all outbound (ECR pull, CloudWatch logs)"
}


#ECR 
resource "aws_ecr_repository" "php_app" {
  name                 = local.app_name
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true #NOTE: Set to false in production

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "php_app" {
  repository = aws_ecr_repository.php_app.name

  policy = jsonencode({
    rules = [
      {
        # Delete untagged images after 1 day
        rulePriority = 1
        description  = "Remove untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        # Keep last 10 CI build images (sha-* tags)
        rulePriority = 2
        description  = "Keep last 10 CI build images (sha-* tags)"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["sha-"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      },
      {
        # Keep last N release images (v* tags)
        rulePriority = 3
        description  = "Keep last ${var.image_retention_count} release images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = var.image_retention_count
        }
        action = { type = "expire" }
      }
    ]
  })
}


# CloudWatch Logs
resource "aws_cloudwatch_log_group" "php_app" {
  name              = "/ecs/${local.name_prefix}-${local.app_name}"
  retention_in_days = 7

  tags = { Name = "${local.name_prefix}-${local.app_name}" }
}


# ALB
# In production, add HTTPS listener (port 443) with ACM certificate.
# HTTP-only is used here to keep the lab environment
resource "aws_lb" "alb" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.default.ids

  enable_deletion_protection = false # Set to true in production

  tags = { Name = "${local.name_prefix}-alb" }
}

resource "aws_lb_target_group" "php_app" {
  name        = "${local.name_prefix}-${local.app_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip" # required for Fargate

  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  # alb target group deregistration for decomission
  deregistration_delay = 30

  tags = { Name = "${local.name_prefix}-${local.app_name}-tg" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.php_app.arn
  }

  tags = { Name = "${local.name_prefix}-http-listener" }
}


# ECS cluster
resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "${local.name_prefix}-cluster" }
}


# ECS Task Definition
resource "aws_ecs_task_definition" "php_app" {
  family                   = "${local.name_prefix}-${local.app_name}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = local.app_name
      image     = "${aws_ecr_repository.php_app.repository_url}:${var.app_image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "PORT", value = tostring(var.container_port) },
        { name = "APP_NAME", value = local.app_name },
        { name = "APP_VERSION", value = var.app_image_tag },
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.php_app.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = local.app_name
        }
      }
    }
  ])

  tags = { Name = "${local.name_prefix}-${local.app_name}" }
}


# ECS Service
# ECS automatically rolls back to the previous task definition.

resource "aws_ecs_service" "php_app" {
  name            = "${local.name_prefix}-${local.app_name}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.php_app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # Zero-downtime rolling deployment
  deployment_minimum_healthy_percent = 100 #min % task should be healthy during deployment
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 60 #60 seconds to check app is healthy

  deployment_circuit_breaker { # enables rollback for ECS
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true # Starting in default vpc, public subnet. For prod private vpc with NAT. ECR and CLoudwatch via VPC enpoints.
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.php_app.arn
    container_name   = local.app_name
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.http]

  tags = { Name = "${local.name_prefix}-${local.app_name}" }

  # Ignore changes to task_definition and desired_count — managed by CI/CD
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}
