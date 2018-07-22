# security groups

resource "aws_security_group" "public" {
  name        = "${local.vpc_name}-public"
  description = "Public resources in VPC ${local.vpc_name}"
  vpc_id      = "${module.vpc.vpc_id}"

  tags {
    tier        = "public"
    environment = "production"
    datacenter  = "${var.datacenter}"
    region      = "${data.aws_region.current.name}"
  }
}

resource "aws_security_group_rule" "public-vpc-ingress" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "all"
  cidr_blocks       = ["${module.vpc.vpc_cidr_block}"]
  security_group_id = "${aws_security_group.public.id}"
}

resource "aws_security_group_rule" "public-ingress" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.public.id}"
}

resource "aws_security_group_rule" "public-egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.public.id}"
}
