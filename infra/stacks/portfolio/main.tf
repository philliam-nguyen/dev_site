# No domain_name variable in this stack. The ADR 0003 amendment of 2026-08-06
# puts the domain in the platform outputs, so app stacks read it back instead
# of holding a copy a typo could desynchronize.
data "terraform_remote_state" "platform" {
  backend = "s3"
  config = {
    bucket = "tf-state-975050064267-us-east-1"
    key    = "platform/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  domain_name = data.terraform_remote_state.platform.outputs.domain_name
}

module "site" {
  source = "../../modules/static-site"

  fqdn              = local.domain_name
  redirect_hosts    = ["www.${local.domain_name}"]
  zone_id           = data.terraform_remote_state.platform.outputs.zone_id
  certificate_arn   = data.terraform_remote_state.platform.outputs.certificate_arn
  oidc_provider_arn = data.terraform_remote_state.platform.outputs.oidc_provider_arn
  github_sub        = "repo:philliam-nguyen/dev_site:ref:refs/heads/main"

  # default-src 'none' makes the zero-JavaScript guarantee a header the
  # browser enforces. Depends on site/astro.config.mjs pinning
  # inlineStylesheets to 'never'; 'auto' would silently break style-src 'self'.
  content_security_policy = join("; ", [
    "default-src 'none'",
    "img-src 'self'",
    "style-src 'self'",
    "font-src 'self'",
    "base-uri 'none'",
    "form-action 'none'",
    "frame-ancestors 'none'",
  ])
}
