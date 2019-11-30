# variables

variable "keybase_username" {
  type = "string"
}

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

variable "apigw_deploy_stage" {
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

variable "plex_docker_image" {
  type = "string"
}

variable "plex_memory_hard_limit" {
  type = "string"
}

variable "plex_memory_soft_limit" {
  type = "string"
}

variable "plex_port" {
  type    = "string"
  default = "32400"
}

variable "plex_tz" {
  type = "string"
}

variable "plex_plex_claim" {
  type = "string"
}

variable "plex_desired_count" {
  type    = "string"
  default = "1"
}

variable "plex_fqdn" {
  type = "string"
}

variable "acme_email" {
  type = "string"
}

variable "someguyontheinternet_cdn_uuid" {
  type = "string"
}

variable "deeryam_cdn_uuid" {
  type = "string"
}

variable "chartmuseum_fqdn" {
  type = "string"
}

variable "chartmuseum_basic_auth_user" {
  type = "string"
}

variable "chartmuseum_basic_auth_pass" {
  type = "string"
}
