# No resources yet, on purpose.
#
# This file exists so the provider can be proved to authenticate before
# anything is created. Both of these are read-only calls: they ask the host
# questions and change nothing, which makes them the right first contact with
# a live API.
#
# The node name is discovered rather than assumed. That is the same lesson as
# the privilege list of 11/09/2026: the host knows, and asking it costs one
# command, while guessing costs a failed apply that reports the wrong cause.

# Note (11/09/2026): this is `proxmox_version`, not the
# `proxmox_virtual_environment_version` that most examples online still show.
# The provider deprecated the longer name and `validate` said so, which is a
# small argument for running validate before ever running plan: it reads the
# provider we actually pinned instead of the documentation someone wrote for
# an older one. The rename lands properly in the provider v1.0.
data "proxmox_version" "host" {}

data "proxmox_virtual_environment_nodes" "available" {}

output "proxmox_version" {
  description = "Proxmox VE version, as reported by the API through the token."
  value       = data.proxmox_version.host.release
}

output "nodes" {
  description = "Node names and whether each is online. Confirms the token can read."
  value = {
    names  = data.proxmox_virtual_environment_nodes.available.names
    online = data.proxmox_virtual_environment_nodes.available.online
  }
}
