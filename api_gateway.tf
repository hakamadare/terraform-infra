# api gateway

locals {
  rest_api_id      = "${data.aws_api_gateway_rest_api.api.id}"
  rest_api_root_id = "${data.aws_api_gateway_rest_api.api.root_resource_id}"
}

resource "aws_api_gateway_resource" "synapsewear" {
  rest_api_id = "${local.rest_api_id}"
  parent_id   = "${local.rest_api_root_id}"
  path_part   = "synapsewear"
}

resource "aws_api_gateway_method" "synapsewear_put" {
  rest_api_id   = "${local.rest_api_id}"
  resource_id   = "${aws_api_gateway_resource.synapsewear.id}"
  http_method   = "PUT"
  authorization = "NONE"
}
