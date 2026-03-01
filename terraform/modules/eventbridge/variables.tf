variable "name_prefix" {
  type = string
}

variable "ingestion_lambda_arn" {
  type = string
}

variable "ingestion_lambda_name" {
  type = string
}

variable "rate_minutes" {
  type    = number
  default = 5
}
