provider "tailscale" {
  # configured via env vars
}

locals {
  tailscale_identifier      = "tailscale"
  tailscale_desired_count   = var.tailscale_instance_count
  tailscale_container_image = "tailscale/tailscale:stable"

  tailscale_route_cidrs = sort(distinct(compact(concat(local.vpc_private_cidrs, local.vpc_database_cidrs, local.vpc_intra_cidrs, local.vpc_elasticache_cidrs))))
}

resource "aws_cloudwatch_log_group" "tailscale" {
  name              = "tailscale"
  retention_in_days = 3
}

resource "aws_ecs_task_definition" "tailscale" {
  execution_role_arn       = aws_iam_role.tailscale.arn
  family                   = local.tailscale_identifier
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  cpu                      = 128
  memory                   = 256

  container_definitions = jsonencode([
    {
      name       = "tailscaled"
      image      = local.tailscale_container_image
      essential  = true
      privileged = true

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          awslogs-region        = local.region
          awslogs-group         = aws_cloudwatch_log_group.tailscale.id
          awslogs-stream-prefix = local.tailscale_identifier
        }
      }

      volumes = [
        {
          name = "/var/lib"
          host = {
            sourcePath = "/var/lib"
          }
        },
        {
          name = "/dev/net/tun"
          host = {
            sourcePath = "/dev/net/tun"
          }
        },
      ]

      environment = [
        {
          name  = "TS_EXTRA_ARGS"
          value = "--advertise-exit-node --hostname=vpc-us-east-1"
        },
        {
          name  = "TS_ACCEPT_DNS"
          value = "false"
        },
        {
          name  = "TS_ROUTES"
          value = join(",", local.tailscale_route_cidrs)
        },
      ]

      secrets = [
        {
          name      = "TS_AUTH_KEY"
          valueFrom = data.aws_ssm_parameter.tailscale_auth_key.arn
        },
      ]
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  tags = local.tags_all
}

resource "aws_ecs_service" "tailscale" {
  name                               = local.tailscale_identifier
  cluster                            = local.ec2_cluster_id
  task_definition                    = aws_ecs_task_definition.tailscale.arn
  desired_count                      = local.tailscale_desired_count
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  propagate_tags                     = "SERVICE"

  capacity_provider_strategy {
    base              = 0
    capacity_provider = "spot"
    weight            = 1
  }

  network_configuration {
    security_groups  = [aws_security_group.tailscale.id]
    subnets          = module.vpc.private_subnets
    assign_public_ip = false
  }

  tags = local.tags_all
}

resource "aws_security_group" "tailscale" {
  name_prefix = "${local.tailscale_identifier}-"
  description = "Tailscale task security group"
  vpc_id      = local.vpc_id
}

resource "aws_security_group_rule" "tailscale_ingress" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = local.vpc_private_cidrs
  security_group_id = aws_security_group.tailscale.id
}

resource "aws_security_group_rule" "tailscale_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.tailscale.id
}

data "aws_iam_policy_document" "tailscale_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}
data "aws_iam_policy_document" "tailscale_task_policy" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]
    resources = [
      replace(data.aws_ssm_parameter.tailscale_auth_key.arn, "ts_auth_key", "*")
    ]
  }
}

resource "aws_iam_role" "tailscale" {
  name_prefix        = "${local.tailscale_identifier}-"
  path               = "/ecs/"
  assume_role_policy = data.aws_iam_policy_document.tailscale_assume_role_policy.json
  tags               = local.tags_all
}

resource "aws_iam_policy" "tailscale" {
  name_prefix = "${local.tailscale_identifier}-"
  description = "ECS task execution policy for ${local.tailscale_identifier}"
  policy      = data.aws_iam_policy_document.tailscale_task_policy.json
}

resource "aws_iam_role_policy_attachment" "tailscale" {
  role       = aws_iam_role.tailscale.name
  policy_arn = aws_iam_policy.tailscale.arn
}

data "aws_ssm_parameter" "tailscale_auth_key" {
  name = "/${local.tailscale_identifier}/ts_auth_key"
}

# resource "aws_ssm_parameter" "tailscale_auth_key" {
# name        = "/${local.tailscale_identifier}/ts_auth_key"
# description = "Auth key enabling service to register with Tailscale"
# type        = "SecureString"
# value       = tailscale_tailnet_key.auth_key.key
# }

# resource "tailscale_tailnet_key" "auth_key" {
# reusable      = true
# ephemeral     = true
# preauthorized = true
# }
