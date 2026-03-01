variable "name_prefix" {
  type = string
}

variable "environment" {
  type = string
}

variable "analytics_lambda_arn" {
  type = string
}

variable "analytics_lambda_name" {
  type = string
}

variable "throttle_rate_limit" {
  type    = number
  default = 1000
}

variable "throttle_burst_limit" {
  type    = number
  default = 2000
}

variable "aws_region" {
  type = string
}
