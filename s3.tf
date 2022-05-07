# s3 buckets

resource "aws_s3_bucket" "infra" {
  bucket = "${local.vpc_name}-infra"
}

resource "aws_s3_bucket_acl" "infra_private" {
  bucket = aws_s3_bucket.infra.id
  acl    = "private"
}
