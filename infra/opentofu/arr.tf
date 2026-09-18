# LXC 107, the *arr stack: second guest to be imported, and the first with bind
# mounts from the host. It has been stopped since 08/09/2026, when the VPN
# credentials failed, which is why it comes before the containers in use: a
# mistake here reaches nothing that is running.
#
# Written from `tofu plan -generate-config-out` on 17/09/2026 and then pruned,
# the same way as the Caddy container. Two values the generator produced were
# rejected by the provider's own validation: an empty `entrypoint`, and
# `cpu.units = 0`, which is what the host reports when no CPU weight is set.
# The MAC address is left out on purpose, since this repository is public and
# the provider keeps the existing address when none is set.
#
# Imported 18/09/2026 without a single change reaching the container. The
# procedure, and the measurements that showed it, are in infra/README.md.

# Kept after the import rather than deleted. If the state file is ever lost,
# the next plan imports this container again instead of trying to create a
# second one.
import {
  to = proxmox_virtual_environment_container.arr
  id = "pve/107"
}

resource "proxmox_virtual_environment_container" "arr" {
  node_name     = "pve"
  vm_id         = 107
  unprivileged  = true
  start_on_boot = true

  # Stopped since 08/09/2026, and it stays stopped: the VPN credentials still
  # fail, and starting it is a decision, not a side effect of an import. This
  # line cannot be pruned as a default: the provider's default is `true`.
  started = false

  delete_unreferenced_disks_on_destroy = false
  purge_on_destroy                     = true

  startup {
    order      = 7
    up_delay   = -1
    down_delay = -1
  }

  console {
    enabled   = true
    tty_count = 2
    type      = "tty"
  }

  cpu {
    architecture = "amd64"
    cores        = 2
  }

  memory {
    dedicated = 2048
    swap      = 512
  }

  disk {
    datastore_id = "local"
    size         = 8
  }

  # Docker inside an unprivileged container needs both. Only `root@pam` may
  # change any flag other than `nesting`.
  features {
    nesting = true
    keyctl  = true
  }

  # `dev1` on the host: the tunnel device gluetun opens for the VPN. Without
  # it the download client has no kill switch to hide behind. Only `root@pam`
  # may configure a device passthrough.
  device_passthrough {
    path = "/dev/net/tun"
    mode = "0660"
  }

  # Bind mounts of host directories, `mp0` and `mp1` on the host. The media
  # library arrives through the host's NFS mount, and the downloads live on the
  # local SSD on purpose, since they are transient. Only `root@pam` may change
  # a bind mount, so these are described here to be matched, never edited.
  mount_point {
    volume    = "/mnt/pve/media-nfs"
    path      = "/data"
    replicate = true
  }

  mount_point {
    volume    = "/var/lib/vz/downloads"
    path      = "/downloads"
    replicate = true
  }

  initialization {
    hostname = "arr"

    ip_config {
      ipv4 {
        address = "192.168.1.90/24"
        gateway = "192.168.1.1"
      }
      ipv6 {
        address = "manual"
      }
    }
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
