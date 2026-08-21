variable "demo_upstream" {
  description = "host:port of the Demo Variant API on the tailnet. Prefer the tailnet IP over the MagicDNS name: nginx resolves hostnames once at startup, and the boot ordering only guarantees MagicDNS after tailscale up."
  type        = string
}
