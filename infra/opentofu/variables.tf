variable "proxmox_endpoint" {
  description = <<-EOT
    Proxmox API endpoint. The flat-network address of the host, which needs
    no tunnel. The Management address 10.10.30.2:8006 has answered too since
    the PC started using its WireGuard tunnel on 16/09/2026; moving there is
    a decision still open. See infra/README.md.
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

variable "ssh_public_key" {
  description = <<-EOT
    Public SSH key for the `ansible` user on guests created by OpenTofu. The
    private half stays in WSL2, where Ansible runs. A public key is not a
    secret; it lives in terraform.tfvars with the other inputs so the code
    stays free of anything tied to one machine.
  EOT
  type        = string
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
