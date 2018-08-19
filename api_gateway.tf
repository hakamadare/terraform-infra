# api gateway

locals {
  rest_api_id             = "${data.aws_api_gateway_rest_api.api.id}"
  rest_api_root_id        = "${data.aws_api_gateway_rest_api.api.root_resource_id}"
  synapsewear_kinesis_uri = "arn:aws:apigateway:${local.region}:firehose:action/PutRecord"
}

resource "aws_api_gateway_resource" "synapsewear" {
  rest_api_id = "${local.rest_api_id}"
  parent_id   = "${local.rest_api_root_id}"
  path_part   = "synapsewear"
}

resource "aws_api_gateway_method" "synapsewear" {
  rest_api_id   = "${local.rest_api_id}"
  resource_id   = "${aws_api_gateway_resource.synapsewear.id}"
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "synapsewear" {
  rest_api_id             = "${local.rest_api_id}"
  resource_id             = "${aws_api_gateway_resource.synapsewear.id}"
  http_method             = "${aws_api_gateway_method.synapsewear.http_method}"
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "${local.synapsewear_kinesis_uri}"
  credentials             = "${aws_iam_role.apigw_role.arn}"
  passthrough_behavior    = "WHEN_NO_TEMPLATES"

  request_templates = {
    "application/json" = "${data.template_file.synapsewear_apigw_request_template_application-json.rendered}"
    "application/x-www-form-urlencoded" = "${data.template_file.synapsewear_apigw_request_template_application-x-www-form-urlencoded.rendered}"
  }

  depends_on = [
    "aws_api_gateway_method.synapsewear",
  ]
}

resource "aws_api_gateway_integration_response" "synapsewear_200" {
  rest_api_id       = "${local.rest_api_id}"
  resource_id       = "${aws_api_gateway_resource.synapsewear.id}"
  http_method       = "${aws_api_gateway_method.synapsewear.http_method}"
  status_code       = "200"
  selection_pattern = "200"

  depends_on = [
    "aws_api_gateway_integration.synapsewear",
  ]
}

resource "aws_api_gateway_integration_response" "synapsewear_500" {
  rest_api_id       = "${local.rest_api_id}"
  resource_id       = "${aws_api_gateway_resource.synapsewear.id}"
  http_method       = "${aws_api_gateway_method.synapsewear.http_method}"
  status_code       = "500"
  selection_pattern = "-"

  depends_on = [
    "aws_api_gateway_integration.synapsewear",
  ]
}

resource "aws_api_gateway_method_response" "synapsewear_200" {
  rest_api_id = "${local.rest_api_id}"
  resource_id = "${aws_api_gateway_resource.synapsewear.id}"
  http_method = "${aws_api_gateway_method.synapsewear.http_method}"
  status_code = "200"
}

resource "aws_api_gateway_method_response" "synapsewear_500" {
  rest_api_id = "${local.rest_api_id}"
  resource_id = "${aws_api_gateway_resource.synapsewear.id}"
  http_method = "${aws_api_gateway_method.synapsewear.http_method}"
  status_code = "500"
}

resource "aws_api_gateway_deployment" "synapsewear" {
  rest_api_id = "${local.rest_api_id}"
  stage_name  = "${var.apigw_deploy_stage}"

  depends_on = [
    "aws_api_gateway_integration.synapsewear",
  ]
}

data "template_file" "synapsewear_apigw_request_template_application-json" {
  template = "${file("${path.module}/templates/synapsewear_apigw_request_template_application-json.tmpl")}"

  vars {
    stream = "${aws_kinesis_firehose_delivery_stream.synapsewear.name}"
  }
}

data "template_file" "synapsewear_apigw_request_template_application-x-www-form-urlencoded" {
  template = "${file("${path.module}/templates/synapsewear_apigw_request_template_application-x-www-form-urlencoded.tmpl")}"

  vars {
    stream = "${aws_kinesis_firehose_delivery_stream.synapsewear.name}"
  }
}

data "aws_iam_policy_document" "apigw_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals = {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "synapsewear_apigw_execution" {
  statement {
    actions = [
      "firehose:PutRecord",
    ]

    resources = [
      "${aws_kinesis_firehose_delivery_stream.synapsewear.arn}",
    ]
  }
}

resource "aws_iam_policy" "synapsewear_apigw_execution" {
  name_prefix = "synapsewear_apigw_"
  path        = "/synapsewear/"
  description = "Permit API Gateway to proxy requests to Kinesis Firehose"
  policy      = "${data.aws_iam_policy_document.synapsewear_apigw_execution.json}"
}

resource "aws_iam_role" "apigw_role" {
  name_prefix        = "apigw_"
  assume_role_policy = "${data.aws_iam_policy_document.apigw_assume_role_policy.json}"
}

resource "aws_iam_role_policy_attachment" "synapsewear_apigw_execution" {
  role       = "${aws_iam_role.apigw_role.name}"
  policy_arn = "${aws_iam_policy.synapsewear_apigw_execution.arn}"
}
