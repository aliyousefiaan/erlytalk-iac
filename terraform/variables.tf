variable "project" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "az_suffixes" {
  type    = list(string)
  default = ["a", "b"]
}

variable "environment" {
  type = string
}

variable "vpc_main_cidr" {
  type = string
}

variable "ec2_general_config" {
  type = map(any)
}

variable "keypair_default" {
  type = map(any)
}

variable "internal_domain" {
  type = string
}

variable "public_domain" {
  type = string
}

variable "eks_main_managed_node_group_general_settings" {
  type = object({
    desired_size   = number
    min_size       = number
    max_size       = number
    instance_types = list(string)
    capacity_type  = string
  })
}

variable "eks_main_cert_manager_cluster_issuers" {
  type = list(object({
    name        = string
    acme_server = string
    acme_email  = string
  }))
}
