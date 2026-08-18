variable "domain_name" {
  description = "Apex domain, no trailing dot. The hosted zone must exist."
  type        = string
}

variable "budget_email" {
  description = "Email address to send budget notifications to."
  type        = string
}

variable "monthly_budget_usd" {
  description = "Monthly budget in USD. Covers every stack in the account, not just the site. Re-derive when a stack adds standing cost; see ADR 0003's 2026-08-17 amendment."
  type        = string
  default     = "15"
}
