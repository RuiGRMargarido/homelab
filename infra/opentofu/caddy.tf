# LXC 101, Caddy: the first existing guest brought under OpenTofu, chosen
# because it holds no configuration and no data, so learning the import costs
# nothing if it goes wrong. The same procedure then applies to the guests that
# matter, VM 102 last.
#
# Written from `tofu plan -generate-config-out` on 17/09/2026 and then pruned.
# Values the provider treats as unset (empty strings, zeros, false, empty lists)
# were removed. The generated `entrypoint = ""` failed the provider's own
# validation, which is why a generated file is a draft and not a result. The
# MAC address was left out on purpose: this repository is public, and the
# provider keeps the existing address when none is set.

# Kept after the import rather than deleted. If the state file is ever lost,
# the next plan imports this container again instead of trying to create a
# second one.
import {
  to = proxmox_virtual_environment_container.caddy
  id = "pve/101"
}

resource "proxmox_virtual_environment_container" "caddy" {
  node_name     = "pve"
  vm_id         = 101
  unprivileged  = true
  started       = true
  start_on_boot = true

  # How the provider behaves on destroy, recorded as the import found it. A
  # destroy is refused anyway, see the lifecycle block.
  delete_unreferenced_disks_on_destroy = false
  purge_on_destroy                     = true

  # Matches the host's own `startup: order=4`, so nothing is sent. Changing it
  # needs Sys.Modify on /, refused to this token on purpose, so the boot order
  # stays a manual step for this guest as for every other.
  startup {
    order      = 4
    up_delay   = -1
    down_delay = -1
  }

  console {
    enabled   = true
    tty_count = 2
    type      = "tty"
  }

  disk {
    datastore_id = "local"
    size         = 4
  }

  features {
    nesting = true
  }

  initialization {
    hostname = "caddy"

    ip_config {
      ipv4 {
        address = "192.168.1.83/24"
        gateway = "192.168.1.1"
      }
      # Proxmox's `ip6=manual`: no IPv6 configuration, the practice for every
      # container since 11/08/2026.
      ipv6 {
        address = "manual"
      }
    }
  }

  memory {
    dedicated = 512
    swap      = 512
  }

  network_interface {
    name     = "eth0"
    bridge   = "vmbr0"
    enabled  = true
    firewall = true
  }

  # The Proxmox API does not record which template a container was created
  # from, so the import brings this back empty while the provider requires it.
  # This is the Debian 12 template present on the node, recorded for a rebuild,
  # and ignored in comparisons below, since a difference here would otherwise
  # plan to replace the container.
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
