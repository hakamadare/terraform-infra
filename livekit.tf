locals {
  identifier = "livekit"

  livekit_port_mapping = [
    {
      containerPort = 7880
      protocol      = "tcp"
    },
    {
      containerPort = 7881
      protocol      = "tcp"
    },
    {
      containerPort = 7882
      protocol      = "udp"
    },
  ]
}
resource "aws_cloudwatch_log_group" "livekit" {
  name              = "livekit"
  retention_in_days = 3
}

resource "aws_ecs_task_definition" "livekit" {
  execution_role_arn       = aws_iam_role.livekit.arn
  family                   = local.identifier
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512

  container_definitions = jsonencode([
    {
      name      = local.identifier
      image     = "livekit/livekit-server:v0.15"
      essential = true

      portMappings = local.livekit_port_mapping

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          awslogs-region        = local.region
          awslogs-group         = aws_cloudwatch_log_group.livekit.id
          awslogs-stream-prefix = local.identifier
        }
      }
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  tags = local.tags_all
}

resource "aws_ecs_service" "livekit" {
  name                               = local.identifier
  cluster                            = local.cluster_id
  task_definition                    = aws_ecs_task_definition.livekit.arn
  desired_count                      = 0
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  propagate_tags                     = "SERVICE"

  capacity_provider_strategy {
    base              = 0
    capacity_provider = "FARGATE"
    weight            = 1
  }

  network_configuration {
    security_groups  = [aws_security_group.livekit.id]
    subnets          = module.vpc.private_subnets
    assign_public_ip = false
  }

  tags = local.tags_all
}

resource "aws_security_group" "livekit" {
  name_prefix = "${local.identifier}-"
  description = "LiveKit task security group"
  vpc_id      = local.vpc_id
}

locals {
  livekit_sg_ingress_rules = zipmap(
    local.livekit_port_mapping[*].containerPort,
    local.livekit_port_mapping[*].protocol,
  )
}

resource "aws_security_group_rule" "livekit_ingress" {
  for_each = local.livekit_sg_ingress_rules

  type              = "ingress"
  from_port         = each.key
  to_port           = each.key
  protocol          = each.value
  cidr_blocks       = module.vpc.public_subnets_cidr_blocks
  security_group_id = aws_security_group.livekit.id
}

resource "aws_security_group_rule" "livekit_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.livekit.id
}

data "aws_iam_policy_document" "livekit_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}
data "aws_iam_policy_document" "livekit_task_policy" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "livekit" {
  name_prefix        = "${local.identifier}-"
  path               = "/ecs/"
  assume_role_policy = data.aws_iam_policy_document.livekit_assume_role_policy.json
  tags               = local.tags_all
}

resource "aws_iam_policy" "livekit" {
  name_prefix = "${local.identifier}-"
  description = "ECS task execution policy for ${local.identifier}"
  policy      = data.aws_iam_policy_document.livekit_task_policy.json
}

resource "aws_iam_role_policy_attachment" "livekit" {
  role       = aws_iam_role.livekit.name
  policy_arn = aws_iam_policy.livekit.arn
}
