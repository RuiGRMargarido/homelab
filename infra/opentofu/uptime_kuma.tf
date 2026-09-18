# LXC 108, Uptime Kuma: the monitor, and the third guest to be imported. The
# first two were a container with nothing in it and a stopped one. This one is
# running and watches everything else, so a restart here would be noticed, and
# the measurement around the apply is what shows none happened.
#
# Written from `tofu plan -generate-config-out` on 18/09/2026 and then pruned,
# the same way as Caddy and the *arr stack. The generator's empty `entrypoint`
# failed the provider's own validation once again. There is no `cpu` block:
# the container runs on the provider's defaults, one core, and the import
# brought no block back, as with Caddy. The MAC address is left out on
# purpose, since this repository is public and the provider keeps the existing
# address when none is set.
#
# Imported 18/09/2026 without a single change reaching the container. The
# procedure, and the measurements that showed it, are in infra/README.md.

# Kept after the import rather than deleted. If the state file is ever lost,
# the next plan imports this container again instead of trying to create a
# second one.
import {
  to = proxmox_virtual_environment_container.uptime_kuma
  id = "pve/108"
}

resource "proxmox_virtual_environment_container" "uptime_kuma" {
  node_name     = "pve"
  vm_id         = 108
  unprivileged  = true
  started       = true
  start_on_boot = true

  # The note the web UI shows for this container. The provider's default is an
  # empty note, so leaving this line out would plan to erase it.
  description = "Uptime Kuma - monitorizacao e alertas"

  delete_unreferenced_disks_on_destroy = false
  purge_on_destroy                     = true

  # Matches the host's `startup: order=3`: up right after the firewall and
  # before the services it watches, see docs/MONITORING.md. Changing it needs
  # Sys.Modify on /, refused to this token on purpose.
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
    size         = 8
  }

  # Docker runs inside this container: beside `eth0`, the import read the
  # addresses of `docker0` and of a user-defined Docker network. Docker in an
  # unprivileged container needs both flags, and only `root@pam` may change
  # any flag other than `nesting`.
  features {
    nesting = true
    keyctl  = true
  }

  initialization {
    hostname = "monitor"

    ip_config {
      ipv4 {
        address = "192.168.1.91/24"
        gateway = "192.168.1.1"
      }
      ipv6 {
        address = "manual"
      }
    }
  }

  # On the flat network by design, so that an alert does not depend on the
  # firewall it watches (docs/MONITORING.md). Unlike Caddy and the *arr stack,
  # its interface has the Proxmox firewall flag off; recorded as found.
  network_interface {
    name     = "eth0"
    bridge   = "vmbr0"
    enabled  = true
    firewall = false
  }

  # The Proxmox API does not record which template a container was created
  # from, so the import brings this back empty while the provider requires it.
  # The container runs Debian 12.12, the version of the template present on
  # the node, which is recorded here for a rebuild and ignored in comparisons
  # below.
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
