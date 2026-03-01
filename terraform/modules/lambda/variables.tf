variable "name_prefix" { type = string }
variable "s3_artifacts_bucket" { type = string }
variable "kinesis_raw_stream_arn" { type = string }
variable "kinesis_raw_stream_name" { type = string }
variable "s3_raw_bucket" { type = string }
variable "dynamodb_table_names" { type = map(string) }
variable "sns_alerts_arn" { type = string }
variable "sns_trending_arn" { type = string }
variable "reddit_secret_name" { type = string }
variable "reddit_subreddits" { type = string }
variable "posts_per_run" { type = number }
variable "iam_roles" { type = map(string) }
variable "log_retention_days" {
  type    = number
  default = 30
}
variable "tracing_mode" {
  type    = string
  default = "Active"
}
variable "aws_region" { type = string }
