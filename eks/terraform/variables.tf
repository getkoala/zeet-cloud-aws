variable "region" {
  type = string
}

variable "aws_account_id" {
  type = string
}

variable "role_arn" {
  type    = string
}

variable "cluster_id" {
  type    = string
}

variable "cluster_name" {
  type    = string
}

variable "cluster_version" {
  type    = string
  default = "1.24"
}

variable "cluster_domain" {
  type    = string
}

variable "user_id" {
  type    = string
}

variable "enable_nat" {
  type    = bool
}

variable "enable_gpu" {
  type    = bool
}
