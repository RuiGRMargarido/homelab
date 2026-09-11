terraform {
  # Pinned rather than left open. An infrastructure provider that changes
  # under you is how an `apply` that worked last week destroys something
  # this week. The exact version is recorded in .terraform.lock.hcl, which
  # is committed on purpose.
  required_version = ">= 1.9.0"

  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      # Exact, not a range. Resolved by the first `init` on 11/09/2026 and
      # then written down: upgrading is meant to be a deliberate edit here,
      # not something a future `init` does on its own.
      version = "0.113.1"
    }
  }
}
