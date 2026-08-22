# Managed CachingOptimized: no cookies, query strings, or headers in the cache
# key, compression on. Origin-side Cache-Control headers set at upload time
# handle TTL tuning, so no custom cache policy.
data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_response_headers_policy" "site" {
  name = "${replace(var.fqdn, ".", "-")}-security-headers"

  security_headers_config {
    content_security_policy {
      content_security_policy = var.content_security_policy
      override                = true
    }

    # includeSubDomains commits every future subdomain to HTTPS-only for a
    # year in any browser that has seen this header. preload stays false:
    # .dev is HSTS-preloaded at the TLD level, so submission is redundant.
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = false
      override                   = true
    }

    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
  }
}

resource "aws_cloudfront_function" "redirect" {
  name    = "${replace(var.fqdn, ".", "-")}-canonical-host"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = templatefile("${path.module}/redirect.js.tftpl", { apex = var.fqdn })
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = concat([var.fqdn], var.redirect_hosts)
  price_class         = "PriceClass_100"

  origin {
    # The regional form: avoids a redirect on the first request to a bucket
    # outside us-east-1, and it is the form OAC expects.
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-${local.bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id           = "s3-${local.bucket_name}"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.optimized.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.site.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.redirect.arn
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}
