# LXC 103, WireGuard: the internet-facing leg in the DMZ, and the way in for
# administration. The one privileged container in this homelab, as it was
# created on 29/07/2026. Imported on 18/09/2026 together with LXCs 104 and
# 105, in a single plan, once the procedure had given the same clean plan
# three times in a row; see infra/README.md.
#
# Written from `tofu plan -generate-config-out` and then pruned, the same way
# as the containers before it. The generator's empty `entrypoint` failed the
# provider's own validation again. The MAC address is left out on purpose,
# since this repository is public and the provider keeps the existing address
# when none is set.

# Kept after the import rather than deleted. If the state file is ever lost,
# the next plan imports this container again instead of trying to create a
# second one.
import {
  to = proxmox_virtual_environment_container.wireguard
  id = "pve/103"
}

resource "proxmox_virtual_environment_container" "wireguard" {
  node_name     = "pve"
  vm_id         = 103
  started       = true
  start_on_boot = true

  # Privileged. Written out although `false` is the provider's default,
  # because it is the one fact about this container a reader must not miss:
  # root inside it is UID 0 on the host, held back by AppArmor rather than by
  # a UID shift.
  unprivileged = false

  delete_unreferenced_disks_on_destroy = false
  purge_on_destroy                     = true

  # Matches the host's `startup: order=3`, the same slot as the monitor.
  # Changing it needs Sys.Modify on /, refused to this token on purpose.
  startup {
    order      = 3
    up_delay   = -1
    down_delay = -1
  }

  console {
    enabled   = true
    tty_count = 2
    type      = "tty"
  }

  memory {
    dedicated = 512
    swap      = 512
  }

  disk {
    datastore_id = "local"
    size         = 4
  }

  initialization {
    hostname = "wireguard"

    ip_config {
      ipv4 {
        address = "10.10.10.10/24"
        gateway = "10.10.10.1"
      }
      ipv6 {
        address = "manual"
      }
    }
  }

  # DMZ, VLAN 10. What a connected client may reach beyond it, Trusted and
  # Management, is decided by the firewall's rules (docs/NETWORK.md).
  network_interface {
    name     = "eth0"
    bridge   = "vmbr0"
    enabled  = true
    firewall = true
    vlan_id  = 10
  }

  # The Proxmox API does not record which template a container was created
  # from, so the import brings this back empty while the provider requires it.
  # This is the Debian 12 template present on the node, recorded for a rebuild,
  # and ignored in comparisons below.
  operating_system {
    template_file_id = "local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"
    type             = "debian"
  }

  lifecycle {
    # Any plan that would destroy or replace this container fails instead.
    prevent_destroy = true
    ignore_changes  = [operating_system[0].template_file_id]
  }
}
