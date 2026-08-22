# for_each over hostnames, not count over a list: state addresses are the
# hostnames, so adding or removing one host never touches the others' records.
locals {
  all_hosts = toset(concat([var.fqdn], var.redirect_hosts))
}

resource "aws_route53_record" "a" {
  for_each = local.all_hosts

  zone_id = var.zone_id
  name    = each.value
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "aaaa" {
  for_each = local.all_hosts

  zone_id = var.zone_id
  name    = each.value
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}
