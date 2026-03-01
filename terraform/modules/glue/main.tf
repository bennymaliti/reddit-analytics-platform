resource "aws_glue_catalog_database" "main" {
  name        = "${replace(var.name_prefix, "-", "_")}_db"
  description = "Reddit Analytics Platform Glue Data Catalog"
}

data "aws_iam_policy_document" "glue_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "glue" {
  name               = "${var.name_prefix}-glue"
  assume_role_policy = data.aws_iam_policy_document.glue_assume.json
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_s3" {
  name = "${var.name_prefix}-glue-s3"
  role = aws_iam_role.glue.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::${var.s3_processed_bucket_name}",
          "arn:aws:s3:::${var.s3_processed_bucket_name}/*",
          "arn:aws:s3:::${var.s3_scripts_bucket_name}",
          "arn:aws:s3:::${var.s3_scripts_bucket_name}/*",
      ] },
      { Effect = "Allow"
        Action = ["kms:Decrypt", "kms:GenerateDataKey"]
      Resource = [var.kms_key_arn] },
    ]
  })
}

resource "aws_glue_crawler" "processed" {
  database_name = aws_glue_catalog_database.main.name
  name          = "${var.name_prefix}-crawler"
  role          = aws_iam_role.glue.arn
  schedule      = "cron(0 6 * * ? *)"
  s3_target { path = "s3://${var.s3_processed_bucket_name}/firehose/" }
}

resource "aws_s3_object" "etl_script" {
  bucket = var.s3_scripts_bucket_name
  key    = "glue-scripts/reddit_etl.py"
  source = "${path.root}/../glue_scripts/reddit_etl.py"
  etag   = filemd5("${path.root}/../glue_scripts/reddit_etl.py")
}

resource "aws_glue_job" "etl" {
  name         = "${var.name_prefix}-etl"
  role_arn     = aws_iam_role.glue.arn
  glue_version = "4.0"

  command {
    name            = "glueetl"
    script_location = "s3://${var.s3_scripts_bucket_name}/glue-scripts/reddit_etl.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--TempDir"                          = "s3://${var.s3_scripts_bucket_name}/glue-temp/"
    "--SOURCE_BUCKET"                    = var.s3_processed_bucket_name
    "--OUTPUT_BUCKET"                    = var.s3_processed_bucket_name
  }

  execution_property { max_concurrent_runs = 1 }
  number_of_workers = 2
  worker_type       = "G.1X"
}
