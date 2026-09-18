# LXC 104, Nextcloud: Docker Compose with Nextcloud, MariaDB and Redis, in
# Trusted, with its files on TrueNAS. Imported on 18/09/2026 together with
# LXCs 103 and 105, in a single plan, once the procedure had given the same
# clean plan three times in a row, without a single change reaching any of
# the three. The procedure and the measurements are in infra/README.md.
#
# Written from `tofu plan -generate-config-out` and then pruned, the same way
# as the containers before it. Two values the generator produced failed the
# provider's own validation again: an empty `entrypoint`, and `cpu.units = 0`.
# The MAC address is left out on purpose, since this repository is public and
# the provider keeps the existing address when none is set.

# Kept after the import rather than deleted. If the state file is ever lost,
# the next plan imports this container again instead of trying to create a
# second one.
import {
  to = proxmox_virtual_environment_container.nextcloud
  id = "pve/104"
}

resource "proxmox_virtual_environment_container" "nextcloud" {
  node_name     = "pve"
  vm_id         = 104
  unprivileged  = true
  started       = true
  start_on_boot = true

  delete_unreferenced_disks_on_destroy = false
  purge_on_destroy                     = true

  # Matches the host's `startup: order=5`. Changing it needs Sys.Modify on /,
  # refused to this token on purpose.
  startup {
    order      = 5
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
    size         = 12
  }

  # Docker inside an unprivileged container needs both. Only `root@pam` may
  # change any flag other than `nesting`.
  features {
    nesting = true
    keyctl  = true
  }

  # `mp0` on the host: the Nextcloud dataset on TrueNAS, mounted over NFS by
  # the host and passed in, since an unprivileged container cannot mount NFS
  # itself (docs/STORAGE.md). Only `root@pam` may change a bind mount.
  mount_point {
    volume    = "/mnt/pve/nextcloud-nfs"
    path      = "/mnt/nextcloud-data"
    replicate = true
  }

  initialization {
    hostname = "nextcloud"

    ip_config {
      ipv4 {
        address = "10.10.20.84/24"
        gateway = "10.10.20.1"
      }
    }
  }

  # Trusted, VLAN 20. The only interface is `net1`, named `eth1`; there is no
  # `net0`. The provider numbers interfaces from zero, so a change to this
  # block or to the address above would make it write the interface as
  # `net0`, delete `net1`, and restart the container. Reading it back, as the
  # import did, sends nothing.
  network_interface {
    name     = "eth1"
    bridge   = "vmbr0"
    enabled  = true
    firewall = true
    vlan_id  = 20
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
