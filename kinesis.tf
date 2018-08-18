# kinesis streams

resource "aws_kinesis_stream" "synapsewear" {
  name             = "${local.vpc_name}-synapsewear"
  shard_count      = 1
  retention_period = 24
  encryption_type  = "NONE"

  tags = {
    environment = "production"
    datacenter  = "${var.datacenter}"
    region      = "${local.region}"
  }
}
