# The development machine: Linux Mint 22.3 MATE in the Trusted zone.
#
# Not made the way the k3s node is made, and the reason is worth reading before
# changing anything here. Mint publishes no cloud image: what the project ships
# are live ISOs whose installer has no preseed and no autoinstall. So the path
# used by k3s.tf, download a qcow2, turn it into a disk with `import_from` and
# let cloud-init write the user, the key and the address, does not exist for
# this system. What is described here is the ISO and the shape of the machine;
# the twenty minutes of the installer are a manual step, once, and everything
# installed afterwards belongs to Ansible (infra/ansible/roles/dev_workstation).
#
# It replaces VM 100, the oldest guest in the house and the only one that was
# never written down anywhere. That one was deleted on 21/09/2026, without a
# copy, by decision. The identifier is 110 and not 100 on purpose: the
# pve-exporter labels its series by guest id, and reusing 100 would splice two
# different machines into one line of every graph and of the host's task log.
#
# This VM is not part of the Kubernetes cluster. It is a sibling of VM 109, not
# a node of it and not a workload inside it: a desktop session that lasts is
# the opposite of a pod, which exists to be disposable. What the two share is
# the host's memory, which is the whole reason the decision about this machine
# waited for k3s to be measured instead of estimated.

locals {
  mnt_mate_ipv4 = "10.10.20.12"
}

# Pinned to a release and verified against the checksum Mint publishes in
# sha256sum.txt beside the image. The MATE edition, as the machine's name has
# always said, and because 6 GB is no place for the heaviest desktop: changing
# edition is this URL and this checksum, nothing else.
#
# `upload_timeout` is raised from the provider's 600 second default. This file
# is 3 GB, and a download cut halfway leaves a plan that looks like an error in
# the configuration when it is only a clock.
resource "proxmox_download_file" "mint_22_3_mate" {
  node_name    = "pve"
  datastore_id = "local"
  content_type = "iso"

  url                = "https://mirrors.edge.kernel.org/linuxmint/stable/22.3/linuxmint-22.3-mate-64bit.iso"
  checksum           = "7609294da613b75eea89bb918292125e9f06418a368136fb190466e15bf8c373"
  checksum_algorithm = "sha256"

  upload_timeout = 1800
}

resource "proxmox_virtual_environment_vm" "mnt_mate" {
  node_name   = "pve"
  vm_id       = 110
  name        = "mnt-mate"
  description = "Development machine, Linux Mint 22.3 MATE. Managed by OpenTofu, infra/opentofu/dev.tf. Software by Ansible, roles/dev_workstation"
  tags        = ["opentofu", "dev"]

  # Does not start with the host. A machine used when someone sits down to use
  # it has no business taking 6 GB out of 23.4 at every boot, and there is
  # deliberately no `startup` block either: a boot order needs Sys.Modify on /,
  # which is one of the privileges this token was refused on purpose.
  on_boot = false

  # True so that the first apply leaves it running for the installer, and then
  # ignored for good. Without the `ignore_changes` below, every later apply
  # would push the machine to whatever this line said, starting or stopping it
  # under whoever was using it. It is the opposite of LXC 107, where the
  # declared state is real and enforced; here the power button belongs to a
  # person and the code says so instead of pretending to know.
  started = true

  lifecycle {
    ignore_changes = [started]
  }

  stop_on_destroy = true

  machine = "q35"
  bios    = "seabios"

  # The console is where the installer's password gets typed, and the keyboard
  # in front of it is Spanish. A wrong layout here is found out at the third
  # special character and always at the worst moment. The same `es` is set
  # again inside the system by the Ansible role, so that it does not live only
  # in the memory of whoever clicked through the installer.
  keyboard_layout = "es"

  operating_system {
    type = "l26"
  }

  # `host` for the same reason as the k3s node: this machine runs images and
  # toolchains built by other people, and a generic CPU model is how those fail
  # with `illegal instruction` instead of with a message.
  cpu {
    cores = 2
    type  = "host"
  }

  # Deliberately the smaller of the two sizes the decision allowed. Growing is
  # this number and an apply; the reason to start low is that the Jellyfin and
  # Nextcloud migrations will want the same memory, and this machine can be off
  # while they run.
  memory {
    dedicated = 6144
  }

  scsi_hardware = "virtio-scsi-single"

  # 48 GB holds two IDEs, a JDK and Docker images with room to spare. Disk, not
  # memory, is what will run out first here, and growing it is this number plus
  # a growpart and a resize2fs inside. It only works upwards: neither the
  # provider nor Proxmox shrinks a disk, which is why starting at 48 is safe
  # and starting at 200 would have no way back.
  disk {
    datastore_id = "local"
    interface    = "scsi0"
    size         = 48
    file_format  = "qcow2"
    iothread     = true
    discard      = "on"
    ssd          = true
  }

  # The installer, and only for the installation. It comes out in a second
  # apply once Mint is on the disk, together with the boot order below.
  #
  # `plan` prints `enabled = false` inside this block and it means nothing here:
  # the attribute is deprecated, and the creation path of the provider does not
  # read it at all. What attaches the drive is this block having an interface
  # (proxmoxtf/resource/vm/vm.go, v0.113.1, lines 3061 and 3296). Checked in the
  # source rather than assumed, because the failure would have been a VM with an
  # empty drive and no way to boot.
  cdrom {
    file_id   = proxmox_download_file.mint_22_3_mate.id
    interface = "ide2"
  }

  boot_order = ["ide2", "scsi0"]

  network_device {
    bridge  = "vmbr0"
    vlan_id = 20
    model   = "virtio"
  }

  # A real graphical adapter, unlike the k3s node, which writes its console to
  # a serial port. This one is looked at: by noVNC during the installation, and
  # by NoMachine afterwards.
  vga {
    type = "std"
  }

  # Off for the first boot, exactly as the k3s node was. The Mint ISO does not
  # install qemu-guest-agent, and with this enabled the provider waits for
  # addresses nobody is going to give it. Ansible installs the agent, and then
  # a second apply turns this to true.
  agent {
    enabled = false
  }

  # No `initialization` block: cloud-init is not part of this system, and the
  # address is set inside by infra/ansible/bootstrap-mint.sh.
}

output "mnt_mate_address" {
  description = "Address the development machine is given by bootstrap-mint.sh."
  value       = local.mnt_mate_ipv4
}
