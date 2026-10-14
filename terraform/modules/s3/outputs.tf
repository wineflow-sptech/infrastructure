output "bucket_id" {
  description = "ID/Name do bucket S3"
  value       = local.bucket_full_name
}

output "bucket_arn" {
  description = "ARN do bucket S3"
  value       = "arn:aws:s3:::${local.bucket_full_name}"
}
