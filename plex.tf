# plex service

locals {
  plex_fqdn               = "${var.plex_fqdn}"
  plex_name               = "plex-${var.env}"
  plex_desired_count      = "${var.plex_desired_count}"
  plex_image              = "${var.plex_docker_image}"
  plex_database_name      = "plex-${var.env}-database"
  plex_transcode_name     = "plex-${var.env}-transcode"
  plex_media_name         = "plex-${var.env}-media"
  plex_memory             = "${var.plex_memory_hard_limit}"
  plex_memory_reservation = "${var.plex_memory_soft_limit}"
  plex_tz                 = "${var.plex_tz}"
  plex_plex_claim         = "${var.plex_plex_claim}"
  plex_advertise_ip       = "http://${local.plex_fqdn}:${local.plex_port}/"
  plex_port               = "${var.plex_port}"
}

resource "aws_ecs_task_definition" "plex" {
  family                   = "${local.plex_name}"
  container_definitions    = "${data.template_file.plex_container_definitions.rendered}"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = "${data.aws_iam_role.plex_ecs_execution_role.arn}"

  volume {
    name      = "${local.plex_database_name}"
    host_path = "${local.ecs_volumes_path}/${local.plex_database_name}"
  }

  volume {
    name      = "${local.plex_transcode_name}"
    host_path = "${local.ecs_volumes_path}/${local.plex_transcode_name}"
  }

  volume {
    name      = "${local.plex_media_name}"
    host_path = "${local.ecs_volumes_path}/${local.plex_media_name}"
  }
}

data "local_file" "plex" {
  filename = "${path.module}/templates/p_c_d_rendered.json"
}

resource "aws_ecs_service" "plex" {
  name            = "${local.plex_name}"
  cluster         = "${module.infra.cluster_id}"
  task_definition = "${aws_ecs_task_definition.plex.arn}"
  desired_count   = "${local.plex_desired_count}"
  iam_role        = "${data.aws_iam_role.ecs_service_role.arn}"
  launch_type     = "EC2"

  ordered_placement_strategy {
    type  = "spread"
    field = "host"
  }

  ordered_placement_strategy {
    type  = "binpack"
    field = "memory"
  }

  load_balancer {
    target_group_arn = "${aws_lb_target_group.plex.arn}"
    container_name   = "${local.plex_name}"
    container_port   = "${local.plex_port}"
  }

  depends_on = [
    "aws_lb_target_group.plex",
    "aws_lb_listener.plex_pms",
  ]
}

data "aws_iam_role" "plex_ecs_execution_role" {
  name = "ecsTaskExecutionRole"
}

data "template_file" "plex_container_definitions" {
  template = "${path.module}/templates/plex_container_definitions.json.tmpl"

  vars {
    name                  = "${local.plex_name}-pms"
    image                 = "${local.plex_image}"
    memory                = "${local.plex_memory}"
    memoryReservation     = "${local.plex_memory_reservation}"
    port                  = "${local.plex_port}"
    tz                    = "${local.plex_tz}"
    plex_claim            = "${local.plex_plex_claim}"
    advertise_ip          = "${local.plex_advertise_ip}"
    database_volume       = "${local.plex_database_name}"
    transcode_volume      = "${local.plex_transcode_name}"
    media_volume          = "${local.plex_media_name}"
    awslogs_group         = "${local.plex_name}"
    awslogs_region        = "${local.region}"
    awslogs_stream_prefix = "pms-"
  }
}

resource "aws_lb_target_group" "plex" {
  name_prefix = "plex-"
  port        = "${local.plex_port}"
  protocol    = "HTTPS"
  vpc_id      = "${module.vpc.vpc_id}"

  stickiness {
    type    = "lb_cookie"
    enabled = false
  }

  tags = {
    "application" = "${local.plex_name}"
    "environment" = "${var.env}"
    "datacenter"  = "${var.datacenter}"
    "region"      = "${local.region}"
  }
}

resource "aws_lb" "plex" {
  name_prefix        = "plex-"
  internal           = false
  load_balancer_type = "application"
  enable_http2       = true

  subnets = ["${module.vpc.public_subnets}"]

  security_groups = ["${data.aws_security_group.ecs.id}"]
}

resource "aws_lb_listener" "plex_pms" {
  load_balancer_arn = "${aws_lb.plex.arn}"
  port              = "${local.plex_port}"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${aws_acm_certificate.plex.arn}"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.plex.arn}"
  }
}

resource "aws_acm_certificate" "plex" {
  domain_name       = "${local.plex_fqdn}"
  validation_method = "DNS"

  tags {
    application = "${local.plex_name}"
    environment = "${var.env}"
    datacenter  = "${var.datacenter}"
    region      = "${local.region}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "plex" {
  certificate_arn         = "${aws_acm_certificate.plex.arn}"
  validation_record_fqdns = ["${aws_route53_record.plex_cert_validation.fqdn}"]
}

resource "aws_route53_record" "plex_cert_validation" {
  name    = "${aws_acm_certificate.plex.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.plex.domain_validation_options.0.resource_record_type}"
  zone_id = "${data.aws_route53_zone.cloud_vecna_org.zone_id}"
  records = ["${aws_acm_certificate.plex.domain_validation_options.0.resource_record_value}"]
  ttl     = 60
}

resource "aws_cloudwatch_log_group" "plex" {
  name              = "${local.plex_name}"
  retention_in_days = 3
}
