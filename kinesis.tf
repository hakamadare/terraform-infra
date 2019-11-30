# kinesis streams

resource "aws_kinesis_firehose_delivery_stream" "synapsewear" {
  name        = "${local.vpc_name}-synapsewear"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_role.arn
    bucket_arn         = aws_s3_bucket.infra.arn
    prefix             = "synapsewear/"
    buffer_size        = 1
    buffer_interval    = 60
    compression_format = "UNCOMPRESSED"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose.name
      log_stream_name = aws_cloudwatch_log_stream.firehose.name
    }
  }
}

resource "aws_cloudwatch_log_group" "firehose" {
  name_prefix       = "firehose_"
  retention_in_days = 3

  tags = {
    environment = "production"
    datacenter  = var.datacenter
    region      = local.region
  }
}

resource "aws_cloudwatch_log_stream" "firehose" {
  name           = "firehose-synapsewear-production"
  log_group_name = aws_cloudwatch_log_group.firehose.name
}

data "aws_iam_policy_document" "firehose_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "firehose_role" {
  name_prefix        = "firehose_"
  assume_role_policy = data.aws_iam_policy_document.firehose_assume_role_policy.json
}

data "aws_iam_policy_document" "synapsewear_firehose_execution" {
  statement {
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetObject",
      "s3:PutObject",
    ]

    resources = [
      "${aws_s3_bucket.infra.arn}/synapsewear/*",
    ]
  }

  statement {
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
    ]

    resources = [
      aws_s3_bucket.infra.arn,
    ]
  }
}

resource "aws_iam_policy" "synapsewear_firehose_execution" {
  name_prefix = "synapsewear_firehose_"
  path        = "/synapsewear/"
  description = "Permit Kinesis Firehose to write objects to S3"
  policy      = data.aws_iam_policy_document.synapsewear_firehose_execution.json
}

resource "aws_iam_role_policy_attachment" "synapsewear_firehose_execution" {
  role       = aws_iam_role.firehose_role.name
  policy_arn = aws_iam_policy.synapsewear_firehose_execution.arn
}

