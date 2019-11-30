# security groups

resource "aws_security_group" "public" {
  name        = "${local.vpc_name}-public"
  description = "Public resources in VPC ${local.vpc_name}"
  vpc_id      = module.vpc.vpc_id

  tags = {
    tier        = "public"
    environment = "production"
    datacenter  = var.datacenter
    region      = local.region
  }
}

resource "aws_security_group_rule" "public-vpc-ingress" {
  type      = "ingress"
  from_port = 0
  to_port   = 65535
  protocol  = "all"
  # TF-UPGRADE-TODO: In Terraform v0.10 and earlier, it was sometimes necessary to
  # force an interpolation expression to be interpreted as a list by wrapping it
  # in an extra set of list brackets. That form was supported for compatibility in
  # v0.11, but is no longer supported in Terraform v0.12.
  #
  # If the expression in the following list itself returns a list, remove the
  # brackets to avoid interpretation as a list of lists. If the expression
  # returns a single list item then leave it as-is and remove this TODO comment.
  cidr_blocks       = [module.vpc.vpc_cidr_block]
  security_group_id = aws_security_group.public.id
}

resource "aws_security_group_rule" "public-ingress" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.public.id
}

resource "aws_security_group_rule" "public-egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.public.id
}

