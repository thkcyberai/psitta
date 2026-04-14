# ── Log Archive Pipeline ──────────────────────────────────────────────────────
#
# Long-term archive for the /ecs/psitta-api CloudWatch log group. A
# subscription filter on that group streams every log line into a
# Kinesis Firehose delivery stream, which buffers and writes to S3
# partitioned by date. Lifecycle transitions objects to Glacier Instant
# Retrieval at 180 days and expires them at 365 days.
#
# This closes logging gap G1 (30-day retention too short for SOC 2) and
# gap G9 (single log stream) from
# docs/Psitta_Logging_Security_Compliance_Guide_v1.md.
#
# Architecture:
#   ECS task ──awslogs──▶ /ecs/psitta-api  (hot, 90 days)
#                             │
#                    subscription_filter
#                             │
#                             ▼
#                    Kinesis Firehose  (5 MB / 300 s buffer, gzip)
#                             │
#                             ▼
#                    s3://psitta-prod-logs-archive-<acct>/
#                      ecs/psitta-api/year=YYYY/month=MM/day=DD/
#                        0–180 days   S3 Standard (Athena-queryable)
#                      180–365 days   Glacier Instant Retrieval
#                           365 days  Expired

data "aws_caller_identity" "current" {}

locals {
  logs_bucket_name = "${var.project}-${var.environment}-logs-archive-${data.aws_caller_identity.current.account_id}"
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ── S3 Archive Bucket ─────────────────────────────────────────────────────────

resource "aws_s3_bucket" "logs_archive" {
  bucket        = local.logs_bucket_name
  force_destroy = false

  tags = merge(local.common_tags, {
    Name    = local.logs_bucket_name
    Purpose = "cloudwatch-log-archive"
  })
}

resource "aws_s3_bucket_versioning" "logs_archive" {
  bucket = aws_s3_bucket.logs_archive.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs_archive" {
  bucket = aws_s3_bucket.logs_archive.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "logs_archive" {
  bucket = aws_s3_bucket.logs_archive.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "logs_archive" {
  bucket     = aws_s3_bucket.logs_archive.id
  depends_on = [aws_s3_bucket_versioning.logs_archive]

  rule {
    id     = "archive-and-expire"
    status = "Enabled"

    filter {}

    transition {
      days          = 180
      storage_class = "GLACIER_IR"
    }

    expiration {
      days = 365
    }

    noncurrent_version_transition {
      noncurrent_days = 180
      storage_class   = "GLACIER_IR"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ── Audit Log Group ───────────────────────────────────────────────────────────
#
# Separate CloudWatch group for security / audit events at the same
# 90-day hot retention as the app group. Created empty; wiring from the
# app is Phase 1 of the logging guide (documents.py, projects.py,
# users.py will call audit_service.log_event + a parallel structlog line
# tagged so the subscription filter or a second appender routes it
# here). See §7 of the logging guide for the event catalog.

resource "aws_cloudwatch_log_group" "audit" {
  name              = "/ecs/${var.project}-api/audit"
  retention_in_days = 90

  tags = merge(local.common_tags, {
    Purpose = "security-audit-events"
  })
}

# ── Firehose → S3 Delivery Stream ─────────────────────────────────────────────

resource "aws_iam_role" "firehose_to_s3" {
  name = "${var.project}-firehose-to-s3"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "firehose.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "firehose_to_s3" {
  name = "${var.project}-firehose-to-s3"
  role = aws_iam_role.firehose_to_s3.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:AbortMultipartUpload",
        "s3:GetBucketLocation",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads",
        "s3:PutObject"
      ]
      Resource = [
        aws_s3_bucket.logs_archive.arn,
        "${aws_s3_bucket.logs_archive.arn}/*"
      ]
    }]
  })
}

resource "aws_kinesis_firehose_delivery_stream" "logs_to_s3" {
  name        = "${var.project}-api-logs-to-s3"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_to_s3.arn
    bucket_arn         = aws_s3_bucket.logs_archive.arn
    buffering_size     = 5
    buffering_interval = 300
    compression_format = "GZIP"

    prefix              = "ecs/${var.project}-api/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    error_output_prefix = "ecs/${var.project}-api-errors/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
  }

  depends_on = [aws_iam_role_policy.firehose_to_s3]

  tags = local.common_tags
}

# ── CloudWatch Logs → Firehose Subscription ───────────────────────────────────
#
# CloudWatch assumes cwl_to_firehose and pushes records from the
# subscription filter into the Firehose stream above. Trust is scoped
# to the regional logs service principal with an aws:SourceAccount
# guard to prevent cross-account confused-deputy.

resource "aws_iam_role" "cwl_to_firehose" {
  name = "${var.project}-cwl-to-firehose"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "logs.${var.aws_region}.amazonaws.com"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "cwl_to_firehose" {
  name = "${var.project}-cwl-to-firehose"
  role = aws_iam_role.cwl_to_firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "firehose:PutRecord",
        "firehose:PutRecordBatch",
        "firehose:DescribeDeliveryStream"
      ]
      Resource = aws_kinesis_firehose_delivery_stream.logs_to_s3.arn
    }]
  })
}

resource "aws_cloudwatch_log_subscription_filter" "api_to_firehose" {
  name            = "${var.project}-api-to-firehose"
  log_group_name  = aws_cloudwatch_log_group.api.name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.logs_to_s3.arn
  role_arn        = aws_iam_role.cwl_to_firehose.arn
  distribution    = "ByLogStream"

  depends_on = [aws_iam_role_policy.cwl_to_firehose]
}
