output "MAIN_DISTRIBUTION_ID" {
  value = aws_cloudfront_distribution.main_s3_distribution.id
}

output "MAIN_DISTRIBUTION_ARN" {
  value = aws_cloudfront_distribution.main_s3_distribution.arn
}

output "MAIN_BUCKET_ID" {
  value = aws_s3_bucket.main_bucket.id
}

output "MAIN_BUCKET_ARN" {
  value = aws_s3_bucket.main_bucket.arn
}

output "MAIN_BUCKET_NAME" {
  value = aws_s3_bucket.main_bucket.bucket
}