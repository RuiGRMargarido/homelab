provider "proxmox" {
  endpoint = var.proxmox_endpoint
  insecure = var.proxmox_insecure

  # Token authentication, never a username and password, and never root@pam.
  # The identity is opentofu@pve with the custom OpenTofuProv role: see
  # docs/TOOLING.md for which privileges it holds and which were refused.
  api_token = var.proxmox_api_token

  # Note for later: some provider features (file uploads, certain disk
  # operations) go over SSH to the node rather than through the API. That
  # path is deliberately not configured yet, because it needs a decision
  # about which Unix user it uses. See CHECKLIST.md Phase 4.
}
