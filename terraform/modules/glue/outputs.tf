output "glue_database_name" { value = aws_glue_catalog_database.main.name }
output "glue_crawler_name" { value = aws_glue_crawler.processed.name }
output "glue_job_name" { value = aws_glue_job.etl.name }
