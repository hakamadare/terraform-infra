locals {
  gotosocial_identifier      = "gotosocial"
  gotosocial_domain          = "wrong.tools"
  gotosocial_fqdn            = "gts.${local.gotosocial_domain}"
  gotosocial_port            = 8080
  gotosocial_zone_id         = data.aws_route53_zone.wrong_tools.zone_id
  gotosocial_desired_count   = var.gotosocial_instance_count
  gotosocial_container_image = var.gotosocial_container_image

  gotosocial_route_cidrs = sort(distinct(compact(concat(local.vpc_private_cidrs, local.vpc_database_cidrs, local.vpc_intra_cidrs))))

  gotosocial_container_environment = [
    {
      name  = "GTS_HOST"
      value = local.gotosocial_fqdn
    },
    {
      name  = "GTS_PORT"
      value = tostring(local.gotosocial_port)
    },
    {
      name  = "GTS_ACCOUNT_DOMAIN"
      value = local.gotosocial_domain
    },
    {
      name  = "GTS_DB_TYPE"
      value = "postgres"
    },
    {
      name  = "GTS_DB_ADDRESS"
      value = split(":", module.postgres.db_instance_endpoint)[0]
    },
    {
      name  = "GTS_DB_USER"
      value = local.gotosocial_identifier
    },
    {
      name  = "GTS_DB_DATABASE"
      value = local.gotosocial_identifier
    },
    {
      name  = "GTS_STORAGE_BACKEND"
      value = "s3"
    },
    {
      name  = "GTS_STORAGE_S3_ENDPOINT"
      value = "s3.amazonaws.com"
    },
    {
      name  = "GTS_STORAGE_S3_BUCKET"
      value = aws_s3_bucket.gotosocial.id
    },
    {
      name  = "GTS_LETSENCRYPT_ENABLED"
      value = "false"
    },
    {
      name  = "GTS_ACCOUNTS_REGISTRATION_OPEN"
      value = "false"
    },
    {
      name  = "GTS_OIDC_ENABLED"
      value = "true"
    },
    {
      name  = "GTS_OIDC_IDP_NAME"
      value = "Google"
    },
    {
      name  = "GTS_OIDC_CLIENT_ID"
      value = "717230484973-qt6bkfdkhob6o51smcllskuhb0onjph4.apps.googleusercontent.com"
    },
    {
      name  = "GTS_OIDC_ISSUER"
      value = "https://accounts.google.com"
    },
    {
      name  = "GTS_OIDC_SCOPES"
      value = "openid email profile"
    },
    {
      name  = "GTS_SMTP_HOST"
      value = "smtp-relay.gmail.com"
    },
    {
      name  = "GTS_SMTP_PORT"
      value = "567"
    },
    {
      name  = "GTS_SMTP_FROM"
      value = "admins@wrong.tools"
    },
  ]

  gotosocial_container_secrets = [

    {
      name      = "GTS_DB_PASSWORD"
      valueFrom = data.aws_ssm_parameter.gotosocial["db_password"].arn
    },
    {
      name      = "GTS_OIDC_CLIENT_SECRET"
      valueFrom = data.aws_ssm_parameter.gotosocial["oidc_client_secret"].arn
    },
    {
      name      = "GTS_SMTP_USERNAME"
      valueFrom = data.aws_ssm_parameter.gotosocial["smtp_username"].arn
    },
    {
      name      = "GTS_SMTP_PASSWORD"
      valueFrom = data.aws_ssm_parameter.gotosocial["smtp_password"].arn
    },
    {
      name      = "GTS_STORAGE_S3_ACCESS_KEY"
      valueFrom = data.aws_ssm_parameter.gotosocial["storage_s3_access_key"].arn
    },
    {
      name      = "GTS_STORAGE_S3_SECRET_KEY"
      valueFrom = data.aws_ssm_parameter.gotosocial["storage_s3_secret_key"].arn
    },
  ]

  gotosocial_config_params = zipmap([for i in concat(local.gotosocial_container_environment, local.gotosocial_container_secrets) : i.name], [for i in concat(local.gotosocial_container_environment, local.gotosocial_container_secrets) : lookup(i, "value", "SECRET")])
}

resource "aws_cloudwatch_log_group" "gotosocial" {
  name              = "gotosocial"
  retention_in_days = 3
}

resource "aws_ecs_task_definition" "gotosocial" {
  execution_role_arn       = aws_iam_role.gotosocial.arn
  family                   = local.gotosocial_identifier
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  cpu                      = 128
  memory                   = 256
  task_role_arn            = aws_iam_role.gotosocial.arn

  container_definitions = jsonencode([
    {
      name       = local.gotosocial_identifier
      image      = local.gotosocial_container_image
      essential  = true
      privileged = true

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          awslogs-region        = local.region
          awslogs-group         = aws_cloudwatch_log_group.gotosocial.id
          awslogs-stream-prefix = local.gotosocial_identifier
        }
      }

      portMappings = [
        {
          containerPort = local.gotosocial_port
        }
      ]

      environment = local.gotosocial_container_environment

      secrets = local.gotosocial_container_secrets
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  tags = local.tags_all
}

resource "aws_ecs_service" "gotosocial" {
  name                               = local.gotosocial_identifier
  cluster                            = local.ec2_cluster_id
  task_definition                    = aws_ecs_task_definition.gotosocial.arn
  desired_count                      = local.gotosocial_desired_count
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  propagate_tags                     = "SERVICE"
  enable_ecs_managed_tags            = true
  enable_execute_command             = true
  health_check_grace_period_seconds  = 60

  capacity_provider_strategy {
    base              = 0
    capacity_provider = "spot"
    weight            = 1
  }

  network_configuration {
    security_groups  = [aws_security_group.gotosocial.id]
    subnets          = module.vpc.private_subnets
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = module.gotosocial_alb.target_group_arns[0]
    container_name   = local.gotosocial_identifier
    container_port   = local.gotosocial_port
  }

  tags = local.tags_all
}

resource "aws_security_group" "gotosocial" {
  name_prefix = "${local.gotosocial_identifier}-"
  description = "GoToSocial task security group"
  vpc_id      = local.vpc_id
}

resource "aws_security_group_rule" "gotosocial_ingress" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = aws_security_group.gotosocial_alb.id
  security_group_id        = aws_security_group.gotosocial.id
}

resource "aws_security_group_rule" "gotosocial_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.gotosocial.id
}

data "aws_iam_policy_document" "gotosocial_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "gotosocial_task_policy" {
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
      replace(data.aws_ssm_parameter.gotosocial["db_password"].arn, "db_password", "*")
    ]
  }

  statement {
    actions = [
      "s3:List*",
      "s3:Get*",
      "s3:Put*",
      "s3:Delete*",
    ]
    resources = [
      "${aws_s3_bucket.gotosocial.arn}",
      "${aws_s3_bucket.gotosocial.arn}/*",
    ]
  }
}

locals {
  gotosocial_secrets = [
    "db_password",
    "oidc_client_secret",
    "smtp_username",
    "smtp_password",
    "storage_s3_access_key",
    "storage_s3_secret_key",
  ]
}

data "aws_ssm_parameter" "gotosocial" {
  for_each = toset(local.gotosocial_secrets)
  name     = "/${local.gotosocial_identifier}/${each.value}"
}

resource "aws_iam_role" "gotosocial" {
  name_prefix        = "${local.gotosocial_identifier}-"
  path               = "/ecs/"
  assume_role_policy = data.aws_iam_policy_document.gotosocial_assume_role_policy.json
  tags               = local.tags_all
}

resource "aws_iam_policy" "gotosocial" {
  name_prefix = "${local.gotosocial_identifier}-"
  description = "ECS task execution policy for ${local.gotosocial_identifier}"
  policy      = data.aws_iam_policy_document.gotosocial_task_policy.json
}

resource "aws_iam_role_policy_attachment" "gotosocial" {
  role       = aws_iam_role.gotosocial.name
  policy_arn = aws_iam_policy.gotosocial.arn
}

resource "aws_iam_user_policy_attachment" "gotosocial" {
  user       = aws_iam_user.gotosocial_s3.name
  policy_arn = aws_iam_policy.gotosocial.arn
}

resource "aws_s3_bucket" "gotosocial" {
  bucket_prefix = "${local.gotosocial_identifier}-"
  tags          = local.tags_all
}

resource "aws_s3_bucket_acl" "gotosocial" {
  bucket = aws_s3_bucket.gotosocial.id
  acl    = "private"
}

resource "aws_s3_bucket_lifecycle_configuration" "gotosocial" {
  bucket = aws_s3_bucket.gotosocial.id

  rule {
    id     = "intelligent-tiering"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "INTELLIGENT_TIERING"
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 3
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "gotosocial" {
  bucket = aws_s3_bucket.gotosocial.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

module "gotosocial_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8"

  name_prefix        = "gts-"
  load_balancer_type = "application"
  vpc_id             = local.vpc_id
  subnets            = module.vpc.public_subnets
  security_groups    = [aws_security_group.gotosocial_alb.id]

  https_listeners = [
    {
      port            = 443
      certificate_arn = module.gotosocial_acm.acm_certificate_arn
    }
  ]

  https_listener_rules = [
    {
      actions = [
        {
          type = "forward"
        }
      ]

      conditions = [
        {
          path_patterns = ["*"]
        }
      ]
    }
  ]

  http_tcp_listeners = [
    {
      port        = 80
      protocol    = "HTTP"
      action_type = "redirect"

      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  ]

  target_groups = [
    {
      name_prefix      = "gts-"
      backend_protocol = "HTTP"
      backend_port     = local.gotosocial_port
      target_type      = "ip"
      protocol_version = "HTTP1"

      health_check = {
        enabled             = true
        interval            = 5
        path                = "/"
        port                = "traffic-port"
        healthy_threshold   = 2
        unhealthy_threshold = 3
        timeout             = 2
        protocol            = "HTTP"
      }
    }
  ]

  tags = local.tags_all
}

resource "aws_security_group" "gotosocial_alb" {
  name_prefix = "${local.gotosocial_identifier}-"
  description = "Allow inbound traffic to GoToSocial"
  vpc_id      = local.vpc_id

  tags = local.tags_all
}

resource "aws_security_group_rule" "gotosocial_alb_ingress" {
  for_each = toset(["443", "80"])

  type              = "ingress"
  from_port         = each.value
  to_port           = each.value
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.gotosocial_alb.id
}

resource "aws_security_group_rule" "gotosocial_alb_egress" {
  type                     = "egress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = aws_security_group.gotosocial.id
  security_group_id        = aws_security_group.gotosocial_alb.id
}

resource "aws_route53_record" "gotosocial" {
  for_each = toset(["A", "AAAA"])

  zone_id = local.gotosocial_zone_id
  name    = local.gotosocial_fqdn
  type    = each.value

  alias {
    name                   = module.gotosocial_alb.lb_dns_name
    zone_id                = module.gotosocial_alb.lb_zone_id
    evaluate_target_health = false
  }
}

module "gotosocial_acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 3"

  domain_name = local.gotosocial_fqdn
  zone_id     = local.gotosocial_zone_id
}

resource "local_sensitive_file" "gotosocial_env_file" {
  filename = "${path.module}/.env.gotosocial"
  content  = join("\n", formatlist("%s=%s", keys(local.gotosocial_config_params), values(local.gotosocial_config_params)))
}

resource "aws_iam_user" "gotosocial_s3" {
  name = "gotosocial-s3"
  tags = local.tags_all
}

resource "aws_iam_access_key" "gotosocial_s3" {
  pgp_key = "keybase:hakamadare"
  user    = aws_iam_user.gotosocial_s3.name
}
