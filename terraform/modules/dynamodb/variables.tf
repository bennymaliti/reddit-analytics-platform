variable "name_prefix" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "billing_mode" {
  type    = string
  default = "PAY_PER_REQUEST"
}

variable "raw_posts_ttl_days" {
  type    = number
  default = 30
}

variable "trending_ttl_days" {
  type    = number
  default = 7
}
