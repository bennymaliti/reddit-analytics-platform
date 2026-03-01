terraform {
  backend "s3" {
    bucket         = "reddit-analytics-tfstate-919399847940"
    key            = "reddit-analytics/terraform.tfstate"
    region         = "eu-west-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
