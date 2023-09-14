locals {
  mastodon_identifier      = "mastodon"
  mastodon_domain          = "wrong.tools"
  mastodon_fqdn            = "mas.${local.mastodon_domain}"
  mastodon_static_fqdn     = "static.${local.mastodon_domain}"
  mastodon_port            = 3000
  mastodon_zone_id         = data.aws_route53_zone.wrong_tools.zone_id
  mastodon_desired_count   = var.mastodon_instance_count
  mastodon_container_image = var.mastodon_container_image

  mastodon_route_cidrs = sort(distinct(compact(concat(local.vpc_private_cidrs, local.vpc_database_cidrs, local.vpc_intra_cidrs))))

  mastodon_container_environment = [
    {
      name  = "LOCAL_DOMAIN"
      value = local.mastodon_domain
    },
    {
      name  = "WEB_DOMAIN"
      value = local.mastodon_fqdn
    },
    {
      name  = "ALTERNATE_DOMAINS"
      value = local.mastodon_domain
    },
    {
      name  = "AUTHORIZED_FETCH"
      value = "true"
    },
    {
      name  = "RAILS_ENV"
      value = "production"
    },
    {
      name  = "RAILS_SERVE_STATIC_FILES"
      value = "true"
    },
    {
      name  = "RAILS_LOG_LEVEL"
      value = "warn"
    },
    {
      name  = "NODE_ENV"
      value = "production"
    },
    {
      name  = "PREPARED_STATEMENTS"
      value = "false"
    },
    {
      name  = "DB_HOST"
      value = split(":", module.postgres.db_instance_endpoint)[0]
    },
    {
      name  = "REDIS_HOST"
      value = aws_elasticache_cluster.redis.cache_nodes[0].address
    },
    {
      name  = "REDIS_NAMESPACE"
      value = local.mastodon_identifier
    },
    {
      name  = "ES_ENABLED"
      value = "false"
    },
    {
      name  = "DEFAULT_LOCALE"
      value = "en"
    },
    {
      name  = "USER_ACTIVE_DAYS"
      value = "30"
    },
    {
      name  = "SMTP_SERVER"
      value = "smtp-relay.gmail.com"
    },
    {
      name  = "SMTP_PORT"
      value = "567"
    },
    {
      name  = "SMTP_TLS"
      value = "true"
    },
    {
      name  = "SMTP_AUTH_METHOD"
      value = "plain"
    },
    {
      name  = "SMTP_DELIVERY_METHOD"
      value = "smtp"
    },
    {
      name  = "SMTP_CA_FILE"
      value = "/etc/ssl/certs/ca-certificates.crt"
    },
    {
      name  = "SMTP_FROM_ADDRESS"
      value = "admins@wrong.tools"
    },
    {
      name  = "S3_ENABLED"
      value = "true"
    },
    {
      name  = "S3_ENDPOINT"
      value = "https://s3.amazonaws.com"
    },
    {
      name  = "S3_BUCKET"
      value = aws_s3_bucket.mastodon.id
    },
    {
      name  = "S3_ALIAS_HOST"
      value = local.mastodon_static_fqdn
    },
    {
      name  = "OIDC_ENABLED"
      value = "true"
    },
    {
      name  = "OIDC_DISPLAY_NAME"
      value = "Google"
    },
    {
      name  = "OIDC_DISCOVERY"
      value = "true"
    },
    {
      name  = "OIDC_ISSUER"
      value = "https://accounts.google.com"
    },
    {
      name  = "OIDC_CLIENT_ID"
      value = "911320871583-722vdv7sagjt6sj5tgjvrh0j92qmjs3o.apps.googleusercontent.com"
    },
    {
      name  = "OIDC_SCOPE"
      value = "openid,email,profile"
    },
    {
      name  = "OIDC_UID_FIELD"
      value = "preferred_username"
    },
    {
      name  = "OIDC_REDIRECT_URI"
      value = "https://${local.mastodon_fqdn}/auth/auth/openid_connect/callback"
    },
    {
      name  = "OIDC_SECURITY_ASSUME_EMAIL_IS_VERIFIED"
      value = "true"
    },
    {
      name  = "OMNIAUTH_ONLY"
      value = "false"
    },
  ]

  mastodon_container_secrets = [
    {
      name      = "SECRET_KEY_BASE"
      valueFrom = data.aws_ssm_parameter.mastodon["secret_key_base"].arn
    },
    {
      name      = "OTP_SECRET"
      valueFrom = data.aws_ssm_parameter.mastodon["otp_secret"].arn
    },
    {
      name      = "VAPID_PRIVATE_KEY"
      valueFrom = data.aws_ssm_parameter.mastodon["vapid_private_key"].arn
    },
    {
      name      = "VAPID_PUBLIC_KEY"
      valueFrom = data.aws_ssm_parameter.mastodon["vapid_public_key"].arn
    },
    {
      name      = "DB_PASS"
      valueFrom = data.aws_ssm_parameter.mastodon["db_pass"].arn
    },
    {
      name      = "OIDC_CLIENT_SECRET"
      valueFrom = data.aws_ssm_parameter.mastodon["oidc_client_secret"].arn
    },
    {
      name      = "SMTP_LOGIN"
      valueFrom = data.aws_ssm_parameter.mastodon["smtp_login"].arn
    },
    {
      name      = "SMTP_PASSWORD"
      valueFrom = data.aws_ssm_parameter.mastodon["smtp_password"].arn
    },
  ]

  mastodon_config_params = zipmap([for i in concat(local.mastodon_container_environment, local.mastodon_container_secrets) : i.name], [for i in concat(local.mastodon_container_environment, local.mastodon_container_secrets) : lookup(i, "value", "SECRET")])

  mastodon_memory_soft_limit = 512
  mastodon_memory_hard_limit = 1024
  mastodon_cpu_limit         = 1024

  mastodon_site_tags = {
    site = local.mastodon_fqdn
  }

  mastodon_tags = merge(local.tags_all, local.mastodon_site_tags)
}

resource "aws_cloudwatch_log_group" "mastodon" {
  name              = "mastodon"
  retention_in_days = 3
}

resource "aws_ecs_task_definition" "mastodon" {
  execution_role_arn       = aws_iam_role.mastodon.arn
  family                   = local.mastodon_identifier
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  cpu                      = local.mastodon_cpu_limit
  task_role_arn            = aws_iam_role.mastodon.arn

  container_definitions = jsonencode([
    {
      name              = local.mastodon_identifier
      image             = local.mastodon_container_image
      cpu               = local.mastodon_cpu_limit
      memoryReservation = local.mastodon_memory_soft_limit
      essential         = true
      privileged        = true

      mountPoints = []
      volumesFrom = []

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          awslogs-region        = local.region
          awslogs-group         = aws_cloudwatch_log_group.mastodon.id
          awslogs-stream-prefix = local.mastodon_identifier
        }
      }

      portMappings = [
        {
          containerPort = local.mastodon_port,
          hostPort      = local.mastodon_port,
          protocol      = "tcp",
        }
      ]

      environment = local.mastodon_container_environment

      secrets = local.mastodon_container_secrets
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  tags = local.mastodon_tags
}

resource "aws_ecs_service" "mastodon" {
  name                               = local.mastodon_identifier
  cluster                            = local.ec2_cluster_id
  task_definition                    = aws_ecs_task_definition.mastodon.arn
  desired_count                      = local.mastodon_desired_count
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 0
  propagate_tags                     = "SERVICE"
  enable_ecs_managed_tags            = true
  enable_execute_command             = true
  health_check_grace_period_seconds  = 600

  capacity_provider_strategy {
    base              = 0
    capacity_provider = "spot"
    weight            = 1
  }

  network_configuration {
    security_groups  = [aws_security_group.mastodon.id]
    subnets          = module.vpc.private_subnets
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = module.mastodon_alb.target_group_arns[0]
    container_name   = local.mastodon_identifier
    container_port   = local.mastodon_port
  }

  tags = local.mastodon_tags
}

resource "aws_security_group" "mastodon" {
  name_prefix = "${local.mastodon_identifier}-"
  description = "Mastodon task security group"
  vpc_id      = local.vpc_id
}

resource "aws_security_group_rule" "mastodon_ingress" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = aws_security_group.mastodon_alb.id
  security_group_id        = aws_security_group.mastodon.id
}

resource "aws_security_group_rule" "mastodon_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.mastodon.id
}

data "aws_iam_policy_document" "mastodon_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "mastodon_task_policy" {
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
      replace(data.aws_ssm_parameter.mastodon["db_pass"].arn, "db_pass", "*")
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
      "${aws_s3_bucket.mastodon.arn}",
      "${aws_s3_bucket.mastodon.arn}/*",
    ]
  }
}

locals {
  mastodon_secrets = [
    "db_pass",
    "oidc_client_secret",
    "otp_secret",
    "secret_key_base",
    "smtp_login",
    "smtp_password",
    "vapid_private_key",
    "vapid_public_key",
  ]
}

data "aws_ssm_parameter" "mastodon" {
  for_each = toset(local.mastodon_secrets)
  name     = "/${local.mastodon_identifier}/${each.value}"
}

resource "aws_iam_role" "mastodon" {
  name_prefix        = "${local.mastodon_identifier}-"
  path               = "/ecs/"
  assume_role_policy = data.aws_iam_policy_document.mastodon_assume_role_policy.json
  tags               = local.mastodon_tags
}

resource "aws_iam_policy" "mastodon" {
  name_prefix = "${local.mastodon_identifier}-"
  description = "ECS task execution policy for ${local.mastodon_identifier}"
  policy      = data.aws_iam_policy_document.mastodon_task_policy.json
}

resource "aws_iam_role_policy_attachment" "mastodon" {
  role       = aws_iam_role.mastodon.name
  policy_arn = aws_iam_policy.mastodon.arn
}

resource "aws_route53_record" "wrong_tools_google_site_verification" {
  zone_id = local.mastodon_zone_id
  type    = "CNAME"
  name    = "f2xlyh4c7si5"
  ttl     = 300
  records = ["gv-gt2lrmqs7yzl54.dv.googlehosted.com"]
}

resource "aws_route53_record" "wrong_tools_apex_txt" {
  zone_id = local.mastodon_zone_id
  type    = "TXT"
  name    = ""
  ttl     = 3600
  records = ["v=spf1 include:_spf.google.com ~all"]
}

resource "aws_route53_record" "wrong_tools_google_mx" {
  zone_id = local.mastodon_zone_id
  type    = "MX"
  name    = ""
  ttl     = 3600

  records = [
    "1 aspmx.l.google.com.",
    "5 alt1.aspmx.l.google.com.",
    "5 alt2.aspmx.l.google.com.",
    "10 alt3.aspmx.l.google.com.",
    "10 alt4.aspmx.l.google.com.",
  ]
}

data "aws_iam_policy_document" "mastodon_static_bucket_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.mastodon.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = module.mastodon_static.cloudfront_origin_access_identity_iam_arns
    }
  }
}

resource "aws_s3_bucket" "mastodon" {
  bucket_prefix = "${local.mastodon_identifier}-"
  tags          = local.mastodon_tags
}

resource "aws_s3_bucket_policy" "mastodon_static_bucket_policy" {
  bucket = aws_s3_bucket.mastodon.id
  policy = data.aws_iam_policy_document.mastodon_static_bucket_policy.json
}

resource "aws_s3_bucket_acl" "mastodon" {
  bucket = aws_s3_bucket.mastodon.id
  acl    = "private"
}

resource "aws_s3_bucket_lifecycle_configuration" "mastodon" {
  bucket = aws_s3_bucket.mastodon.id

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

module "mastodon_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8"

  name_prefix        = "mas-"
  load_balancer_type = "application"
  vpc_id             = local.vpc_id
  subnets            = module.vpc.public_subnets
  security_groups    = [aws_security_group.mastodon_alb.id]

  https_listeners = [
    {
      port            = 443
      certificate_arn = module.mastodon_acm.acm_certificate_arn
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
      name_prefix      = "mas-"
      backend_protocol = "HTTP"
      backend_port     = local.mastodon_port
      target_type      = "ip"
      protocol_version = "HTTP1"

      health_check = {
        enabled             = true
        interval            = 5
        path                = "/api/v2/instance"
        port                = "traffic-port"
        healthy_threshold   = 2
        unhealthy_threshold = 3
        timeout             = 2
        protocol            = "HTTP"
        matcher             = "200,403"
      }
    }
  ]

  tags = local.mastodon_tags
}

resource "aws_security_group" "mastodon_alb" {
  name_prefix = "${local.mastodon_identifier}-"
  description = "Allow inbound traffic to Mastodon"
  vpc_id      = local.vpc_id

  tags = local.mastodon_tags
}

resource "aws_security_group_rule" "mastodon_alb_ingress" {
  for_each = toset(["443", "80"])

  type              = "ingress"
  from_port         = each.value
  to_port           = each.value
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.mastodon_alb.id
}

resource "aws_security_group_rule" "mastodon_alb_egress" {
  type                     = "egress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = aws_security_group.mastodon.id
  security_group_id        = aws_security_group.mastodon_alb.id
}

resource "aws_route53_record" "mastodon" {
  zone_id = local.mastodon_zone_id
  name    = local.mastodon_fqdn
  type    = "CNAME"
  ttl     = 60

  records = ["vip.masto.host"]

}

module "mastodon_acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 3"

  domain_name = local.mastodon_fqdn
  zone_id     = local.mastodon_zone_id
}

resource "local_sensitive_file" "mastodon_env_file" {
  filename = "${path.module}/.env.mastodon"
  content  = join("\n", formatlist("%s=%s", keys(local.mastodon_config_params), values(local.mastodon_config_params)))
}

module "mastodon_static" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "~> 3"

  aliases = [local.mastodon_static_fqdn]

  comment             = "Static content hosting for Mastodon"
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_100"
  retain_on_delete    = false
  wait_for_deployment = false

  create_origin_access_identity = true

  origin_access_identities = {
    mastodon = "Access to Mastodon bucket"
  }

  origin = {
    mastodon = {
      domain_name = aws_s3_bucket.mastodon.bucket_regional_domain_name

      s3_origin_config = {
        origin_access_identity = "mastodon"
      }
    }
  }

  default_cache_behavior = {
    target_origin_id       = "mastodon"
    viewer_protocol_policy = "allow-all"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    query_string           = true

    cache_policy_id            = data.aws_cloudfront_cache_policy.mastodon_static.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.mastodon_static.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.mastodon_static.id
  }

  viewer_certificate = {
    acm_certificate_arn = module.mastodon_static_cert.acm_certificate_arn
    ssl_support_method  = "sni-only"
  }
}

data "aws_cloudfront_cache_policy" "mastodon_static" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_origin_request_policy" "mastodon_static" {
  name = "Managed-CORS-S3Origin"
}

data "aws_cloudfront_response_headers_policy" "mastodon_static" {
  name = "Managed-CORS-with-preflight-and-SecurityHeadersPolicy"
}

resource "aws_route53_record" "mastodon_static" {
  for_each = toset(["A", "AAAA"])

  zone_id = local.mastodon_zone_id
  name    = local.mastodon_static_fqdn
  type    = each.value

  alias {
    name                   = module.mastodon_static.cloudfront_distribution_domain_name
    zone_id                = module.mastodon_static.cloudfront_distribution_hosted_zone_id
    evaluate_target_health = false
  }

}

module "mastodon_static_cert" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 3"

  domain_name = local.mastodon_static_fqdn
  zone_id     = local.mastodon_zone_id
}
