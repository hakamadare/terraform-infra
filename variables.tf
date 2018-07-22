# variables

variable "env" {
  type = "string"
}

variable "datacenter" {
  type = "string"
}

variable "vpc_name" {
  type = "string"
}

variable "vpc_cidr" {
  type    = "string"
  default = "10.0.0.0/16"
}
