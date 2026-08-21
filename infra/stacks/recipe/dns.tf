resource "aws_route53_record" "demo" {
  zone_id = data.terraform_remote_state.platform.outputs.zone_id
  name    = local.hostname
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}
