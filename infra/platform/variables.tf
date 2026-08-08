variable "domain_name" {
  description = "Apex domain, no trailing dot. The hosted zone must exist."
  type        = string
}

variable "budget_email" {
  description = "Email address to send budget notifications to."
  type        = string
}

variable "monthly_budget_usd" {
  description = "Monthly budget in USD."
  type        = string
  default     = "5"
}
