variable "name_prefix" {
  type = string
}

variable "kms_key_id" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "shard_count" {
  type    = number
  default = 2
}

variable "retention_period_hours" {
  type    = number
  default = 24
}

variable "s3_processed_bucket_arn" {
  type = string
}

variable "s3_processed_bucket_id" {
  type = string
}

variable "firehose_buffer_size_mb" {
  type    = number
  default = 64
}

variable "firehose_buffer_interval_sec" {
  type    = number
  default = 300
}
