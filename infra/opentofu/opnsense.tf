# VM 106, OPNsense: the firewall that routes between the DMZ, Trusted and
# Management, with its WAN leg on a network card of its own. The first VM
# brought under OpenTofu, and imported alone on purpose: VMs are a different
# resource in the provider, and a mistake here cuts off every zone at once.
#
# The rule for importing a VM is stricter than for a container. The pinned
# provider's VM update sends the VM's name on every update, changed or not,
# so any change in the plan, even one that only touches the state, becomes a
# write to this VM's configuration. The import therefore has to plan
# `0 to change`, not merely a harmless change. That is possible because the
# VM read, unlike the container one, fills in `vm_id` and the timeouts itself.
#
# Written from `tofu plan -generate-config-out` on 18/09/2026 and then pruned.
# Three values the generator produced failed the provider's own validation:
# an empty `cpu.affinity`, `cpu.units = 0` and an empty `memory.hugepages`.
# Every attribute left out below was checked against the provider's default
# at the pinned version, so that leaving it out plans no difference. The MAC
# addresses are left out on purpose, since this repository is public and the
# provider keeps the existing addresses when none is set.
#
# Imported 18/09/2026 with a plan of `1 to import, 0 to change`, so the
# provider's update never ran and nothing reached the VM. The measurements are
# in infra/README.md.

# Kept after the import rather than deleted. If the state file is ever lost,
# the next plan imports this VM again instead of trying to create a second one.
import {
  to = proxmox_virtual_environment_vm.opnsense
  id = "pve/106"
}

resource "proxmox_virtual_environment_vm" "opnsense" {
  node_name = "pve"
  vm_id     = 106
  name      = "opnsense"
  on_boot   = true
  started   = true

  # How the provider behaves on destroy, recorded as the import found it. A
  # destroy is refused anyway, see the lifecycle block.
  stop_on_destroy                      = false
  purge_on_destroy                     = true
  delete_unreferenced_disks_on_destroy = true

  # Left at the provider's default, because changing it now would itself be a
  # change, and so a write. It means the next change that needs a reboot
  # restarts the firewall on its own. If that is not wanted, set this to
  # `false` first, in a change of its own.
  reboot_after_update = true

  # Matches the host's `startup: order=2,up=20`: right after TrueNAS, and 20
  # seconds before the next guest. Changing it needs Sys.Modify on /, refused
  # to this token on purpose.
  startup {
    order      = 2
    up_delay   = 20
    down_delay = -1
  }

  # There is no `operating_system` block: `ostype: other` is the provider's
  # default, and the import brought none back.
  bios          = "seabios"
  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["ide0", "ide2", "net0"]

  cpu {
    cores   = 2
    sockets = 1
    type    = "x86-64-v2-AES"
  }

  memory {
    dedicated = 2048
  }

  # The system disk, on IDE as the VM was created. The empty CD drive on
  # `ide2` is not described: the provider did not read one back.
  disk {
    datastore_id = "local"
    interface    = "ide0"
    file_format  = "qcow2"
    size         = 16
  }

  # In this order on purpose. The provider numbers network devices from zero,
  # so a block's position is its identity: net0 is the WAN leg, on `vmbr1`
  # and a card of its own, and net1 to net3 are the DMZ, Trusted and
  # Management, tagged on `vmbr0`. Reordering these blocks would renumber the
  # firewall's interfaces, and inside OPNsense each one is assigned by that
  # number. The Proxmox firewall is off on all four, the provider's default.
  network_device {
    bridge = "vmbr1"
    model  = "virtio"
    queues = 2
  }

  network_device {
    bridge  = "vmbr0"
    vlan_id = 10
    model   = "virtio"
    queues  = 2
  }

  network_device {
    bridge  = "vmbr0"
    vlan_id = 20
    model   = "virtio"
    queues  = 2
  }

  network_device {
    bridge  = "vmbr0"
    vlan_id = 30
    model   = "virtio"
    queues  = 2
  }

  lifecycle {
    # Any plan that would destroy or replace this VM fails instead.
    prevent_destroy = true
  }
}
