locals {
  hostname = "meal-prep.${data.terraform_remote_state.platform.outputs.domain_name}"
}

# The bucket policy admitting CloudFront lives in cdn.tf with the
# distribution, because it conditions on the distribution's ARN.
resource "aws_s3_bucket" "frontend" {
  # The bundle is a CI-rebuilt artifact keyed to a git SHA; nothing in
  # this bucket is the only copy of anything, so destroy may empty it.
  bucket        = "meal-prep-phillip-nguyen-dev"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "meal-prep-frontend"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
