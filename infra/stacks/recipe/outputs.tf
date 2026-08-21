output "hostname" {
  value = local.hostname
}

output "frontend_bucket" {
  value = aws_s3_bucket.frontend.id
}

output "distribution_id" {
  description = "CI needs this for the post-deploy invalidation."
  value       = aws_cloudfront_distribution.this.id
}

output "deploy_role_arn" {
  description = "The role the GitHub Actions workflow assumes."
  value       = aws_iam_role.deploy.arn
}
