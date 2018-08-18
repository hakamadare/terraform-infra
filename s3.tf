# s3 buckets

resource "aws_s3_bucket" "infra" {
  bucket = "${local.vpc_name}-infra"
  region = "${local.region}"
  acl    = "private"
}
