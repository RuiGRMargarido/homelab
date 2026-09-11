variable "proxmox_endpoint" {
  description = <<-EOT
    Proxmox API endpoint. The flat-network address of the host, which is the
    only one reachable from the PC: the Management address 10.10.30.2:8006
    does not answer from here. See infra/README.md for why that matters and
    what the correct long-term fix is.
  EOT
  type        = string
  default     = "https://192.168.1.206:8006/"
}

variable "proxmox_api_token" {
  description = <<-EOT
    The full API token as ONE string: "opentofu@pve!provider=<secret>".
    Not two fields, and not the id on its own. Lives in terraform.tfvars,
    which is gitignored; the real value is in docs/SECRETS.md.
  EOT
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = <<-EOT
    Skip TLS verification. True because the host serves its own self-signed
    certificate. The alternative is trusting the Proxmox CA on this PC, which
    is better and is not worth the step yet on a link that never leaves the
    local network.
  EOT
  type        = bool
  default     = true
}
