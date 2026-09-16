# The k3s node: a single-node Kubernetes cluster in the Trusted zone.
#
# Everything in this file goes through the Proxmox API, and nothing needs SSH
# to the host. That is deliberate. In this provider an SSH path is typically
# needed to upload custom cloud-init files (snippets) and for the older way of
# importing disks, and this node uses neither: the image arrives through
# `download_file`, becomes a disk through `import_from`, and cloud-init uses
# only the built-in user, IP and DNS fields. Every attribute below was checked
# against the schema of the pinned provider, not quoted from an example.

locals {
  k3s_1_ipv4    = "10.10.20.11"
  trusted_gw_ip = "10.10.20.1" # OPNsense on the Trusted zone, as for TrueNAS
}

# Debian 13 generic cloud image, pinned to a dated build instead of `latest`.
# With `latest`, every new Debian build changes the file and OpenTofu would
# propose downloading it again. The checksum comes from the SHA512SUMS file
# published beside the image, and the download is verified against it.
# `proxmox_download_file` rather than `proxmox_virtual_environment_download_file`:
# `validate` flagged the long name as deprecated, and the new one has exactly the
# same fields. The VM below keeps its long name on purpose. The new `proxmox_vm`
# is described by the provider itself as an experimental proof of concept that
# must not be used in production, and the long VM name is not deprecated.
resource "proxmox_download_file" "debian_13" {
  node_name    = "pve"
  datastore_id = "local"
  content_type = "import"

  url                = "https://cloud.debian.org/images/cloud/trixie/20260914-2601/debian-13-genericcloud-amd64-20260914-2601.qcow2"
  checksum           = "95e110dfcdbd0ed8a82a75ed9579802f9950cabf51a810dcc6388e81bc778188713878b9f28d583a0ea602fbf48b35996ae9ad37f584166d8fbd6489df248f53"
  checksum_algorithm = "sha512"
}

resource "proxmox_virtual_environment_vm" "k3s_1" {
  node_name   = "pve"
  vm_id       = 109
  name        = "k3s-1"
  description = "k3s single-node cluster. Managed by OpenTofu, infra/opentofu/k3s.tf"
  tags        = ["opentofu", "k3s"]

  # Starts on its own after a host reboot. There is deliberately no `startup`
  # block. Proxmox treats the boot order as host behaviour and requires
  # Sys.Modify on / to set it, which is one of the privileges refused to this
  # token on purpose; the first apply of 16/09 failed on exactly that. Nothing
  # is lost: guests without an order always start after those that have one,
  # which is where this node belongs anyway.
  on_boot = true
  started = true

  # A node being destroyed needs no clean shutdown, and with the default a
  # destroy against a running VM waits for one.
  stop_on_destroy = true

  machine = "q35"
  bios    = "seabios"

  operating_system {
    type = "l26"
  }

  # `host`, not the provider default `qemu64`. This node will run container
  # images built by third parties, some of which require x86-64-v2 or AVX and
  # fail with `illegal instruction` under a generic CPU. The usual cost of
  # `host` is losing live migration, and there is no second host to migrate
  # to. VM 102 already runs with `host`.
  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 4096
  }

  scsi_hardware = "virtio-scsi-single"

  disk {
    datastore_id = "local"
    interface    = "scsi0"
    import_from  = proxmox_download_file.debian_13.id
    file_format  = "qcow2"
    size         = 32
    iothread     = true
    discard      = "on"
    ssd          = true
  }

  network_device {
    bridge  = "vmbr0"
    vlan_id = 20
    model   = "virtio"
  }

  # Cloud images write their console to the serial port. Without one, the boot
  # is invisible from the Proxmox console, which is exactly when it is needed.
  serial_device {
    device = "socket"
  }

  vga {
    type = "serial0"
  }

  # Disabled on purpose for the first boot. The Debian cloud image does not
  # ship qemu-guest-agent, and with the agent enabled the provider waits for it
  # to report addresses that never come. Ansible installs it; enable it then.
  agent {
    enabled = false
  }

  initialization {
    datastore_id = "local"

    ip_config {
      ipv4 {
        address = "${local.k3s_1_ipv4}/24"
        gateway = local.trusted_gw_ip
      }
    }

    dns {
      servers = [local.trusted_gw_ip]
    }

    # Key-only login for the automation user; no password is set.
    user_account {
      username = "ansible"
      keys     = [var.ssh_public_key]
    }
  }
}

output "k3s_1_address" {
  description = "Address of the k3s node, as configured through cloud-init."
  value       = local.k3s_1_ipv4
}
