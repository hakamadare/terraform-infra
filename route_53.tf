# route 53

data "aws_route53_zone" "vecna_org" {
  name         = "vecna.org."
  private_zone = false
}

data "aws_route53_zone" "cloud_vecna_org" {
  name         = "cloud.vecna.org."
  private_zone = false
}

data "aws_route53_zone" "deer-y_am" {
  name         = "deer-y.am."
  private_zone = false
}

data "aws_route53_zone" "wrong_tools" {
  name         = "wrong.tools"
  private_zone = false
}

