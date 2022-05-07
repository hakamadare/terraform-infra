locals {
  identifier = "livekit"
}
resource "aws_cloudwatch_log_group" "livekit" {
  name              = "livekit"
  retention_in_days = 3
}

resource "aws_ecs_task_definition" "livekit" {
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

      portMappings = [
        {
          containerPort = 7880
        },
        {
          containerPort = 7881
        },
        {
          containerPort = 7882
          protocol      = "udp"
        },
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          awslogs-region        = local.region
          awslogs-group         = local.aws_cloudwatch_log_group.livekit
          awslogs-stream-prefix = local.identifier
        }
      }
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }
}

resource "aws_ecs_service" "livekit" {
  name            = "livekit"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.livekit.arn

  desired_count = 1

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
}
