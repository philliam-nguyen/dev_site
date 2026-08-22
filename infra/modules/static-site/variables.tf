variable "fqdn" {
  description = "Primary hostname this site serves, no trailing dot."
  type        = string
}

variable "redirect_hosts" {
  description = "Hostnames that 301 to fqdn. Empty for subdomain apps."
  type        = list(string)
  default     = []
}

variable "zone_id" {
  description = "Route 53 hosted zone ID from the platform stack."
  type        = string
}

variable "certificate_arn" {
  description = "Validated ACM certificate ARN covering fqdn and redirect_hosts."
  type        = string
}

variable "oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN from the platform stack."
  type        = string
}

variable "github_sub" {
  description = "Exact sub claim allowed to assume the deploy role, e.g. repo:owner/name:ref:refs/heads/main"
  type        = string
}

# A variable rather than a module constant on purpose: the CSP depends on what
# each site's build emits, and a value baked into the module would be either
# wrong for the next consumer or loose enough to be worthless here.
variable "content_security_policy" {
  description = "CSP header value. Site-specific because it depends on what the build emits."
  type        = string
}
