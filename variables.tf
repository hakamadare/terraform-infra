# variables

variable "env" {
  type = "string"
}

variable "datacenter" {
  type = "string"
}

variable "ec2_keypair" {
  type = "string"
}

variable "ecs_servers" {
  type = "string"
}

variable "ecs_min_servers" {
  type    = "string"
  default = 2
}

variable "ecs_instance_type" {
  type = "string"
}

variable "ecs_docker_storage_size" {
  type    = "string"
  default = 22
}

variable "ecs_dockerhub_email" {
  type = "string"
}

variable "ecs_dockerhub_token" {
  type = "string"
}

variable "rest_api_root" {
  type = "string"
}

variable "vpc_name" {
  type = "string"
}

variable "vpc_cidr" {
  type    = "string"
  default = "10.0.0.0/16"
}
