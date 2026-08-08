output "zone_id" {
  description = "Hosted zone ID. Consumed by every app stack."
  value       = data.aws_route53_zone.this.zone_id
}

# Re-exported from the variable, not from the data source, per the ADR 0003
# amendment of 2026-08-06. The data source returns the name with a trailing
# dot; app stacks want the form they can build a subdomain from.
output "domain_name" {
  description = "Apex domain. App stacks read this rather than declaring a copy."
  value       = var.domain_name
}

# The validation resource's arn, not the certificate's. Same string, but
# reading it here means a consumer cannot attach a certificate that ACM has
# not issued yet.
output "certificate_arn" {
  description = "Validated certificate covering the apex and *.apex."
  value       = aws_acm_certificate_validation.this.certificate_arn
}

output "oidc_provider_arn" {
  description = "GitHub Actions OIDC provider. Consumed by every app stack's deploy role."
  value       = aws_iam_openid_connect_provider.github.arn
}
