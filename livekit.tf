locals {
  identifier              = "livekit"
  livekit_desired_count   = var.livekit_instance_count
  livekit_container_image = "livekit/livekit-server:v1.0"

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
      image     = local.livekit_container_image
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

      secrets = [
        {
          name      = "LIVEKIT_KEYS"
          valueFrom = data.aws_ssm_parameter.secrets["livekit_keys"].arn
        },
        {
          name      = "LIVEKIT_CONFIG"
          valueFrom = data.aws_ssm_parameter.secrets["livekit_config"].arn
        }
      ]
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
  cluster                            = local.fargate_cluster_id
  task_definition                    = aws_ecs_task_definition.livekit.arn
  desired_count                      = local.livekit_desired_count
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
    subnets          = module.vpc.public_subnets
    assign_public_ip = true
  }

  dynamic "load_balancer" {
    for_each = toset(local.livekit_port_mapping)

    content {
      target_group_arn = module.livekit_lb.target_group_arns[index(local.livekit_port_mapping, load_balancer.value)]
      container_name   = local.identifier
      container_port   = load_balancer.value.containerPort
    }
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
  cidr_blocks       = ["0.0.0.0/0"]
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

  statement {
    actions = [
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]
    resources = [
      replace(data.aws_ssm_parameter.secrets["livekit_keys"].arn, "livekit_keys", "*")
    ]
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

data "aws_ssm_parameter" "secrets" {
  for_each = toset(["livekit_config", "livekit_keys"])

  name            = "/${local.identifier}/${each.value}"
  with_decryption = false
}

locals {
  livekit_target_groups = [
    for mapping in local.livekit_port_mapping :
    {
      name_prefix      = "${substr(mapping.protocol, 0, 1)}${mapping.containerPort}-"
      backend_protocol = upper(mapping.protocol)
      backend_port     = mapping.containerPort
      target_type      = "ip"

      health_check = {
        port     = "${mapping.protocol == "udp" ? 7880 : "traffic-port"}"
        protocol = "TCP"
      }
    }
  ]

  livekit_https_listeners = [
    for index, mapping in slice(local.livekit_port_mapping, 0, 1) :
    {
      port               = mapping.containerPort
      protocol           = "TLS"
      certificate_arn    = module.livekit_acm.acm_certificate_arn
      target_group_index = index
    }
  ]

  livekit_http_tcp_listeners = [
    for index, mapping in slice(local.livekit_port_mapping, 1, length(local.livekit_port_mapping)) :
    {
      port               = mapping.containerPort
      protocol           = upper(mapping.protocol)
      target_group_index = index + 1
    }
  ]
}

module "livekit_lb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 6.0"

  name_prefix                      = "lk-"
  load_balancer_type               = "network"
  vpc_id                           = local.vpc_id
  subnets                          = module.vpc.public_subnets
  target_groups                    = local.livekit_target_groups
  https_listeners                  = local.livekit_https_listeners
  https_listeners_tags             = local.tags_all
  http_tcp_listeners               = local.livekit_http_tcp_listeners
  http_tcp_listeners_tags          = local.tags_all
  enable_cross_zone_load_balancing = true
  lb_tags                          = local.tags_all
}

resource "aws_route53_record" "livekit" {
  for_each = toset(["A", "AAAA"])

  zone_id = data.aws_route53_zone.wrong_tools.zone_id
  name    = local.identifier
  type    = each.value

  alias {
    name                   = module.livekit_lb.lb_dns_name
    zone_id                = module.livekit_lb.lb_zone_id
    evaluate_target_health = false
  }
}

module "livekit_acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 3.0"

  domain_name         = "${local.identifier}.wrong.tools"
  zone_id             = data.aws_route53_zone.wrong_tools.zone_id
  wait_for_validation = false
  tags                = local.tags_all
}
