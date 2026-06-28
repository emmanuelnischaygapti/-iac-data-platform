resource "aws_glue_catalog_database" "main" {
  name        = "saas_platform_db"
  description = "Glue catalog database for the IaC data platform"
}

resource "aws_glue_crawler" "raw_data" {
  name          = "${var.project_name}-raw-crawler"
  role          = aws_iam_role.glue_crawler.arn
  database_name = aws_glue_catalog_database.main.name
  description   = "Crawls raw S3 data and populates the Glue catalog"

  s3_target {
    path = "s3://${aws_s3_bucket.raw.bucket}/nyc-taxi/"
  }

  schedule = "cron(0 6 * * ? *)" # runs daily at 06:00 UTC

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
    }
  })
}
