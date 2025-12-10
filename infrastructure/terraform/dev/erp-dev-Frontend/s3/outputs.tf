output "bucket_id" {
  value = aws_s3_bucket.frontend.id
}

output "bucket_arn" {
  value = aws_s3_bucket.frontend.arn
}

output "website_endpoint" {
  value = aws_s3_bucket_website_configuration.frontend.website_endpoint
}
