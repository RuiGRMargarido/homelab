#!/bin/bash
# Open the door Ansible uses, in one LXC container.
#
# Ansible reaches every guest the same way: SSH to the guest itself, as the
# user `ansible`, with the key that lives in WSL2. The containers came from a
# template with no SSH server, so that door has to be opened once, from the
# host, with `pct exec`. After this a container is no different from the k3s
# VM: it goes into the inventory and the roles do the rest.
#
# Deliberately not the other way round. Letting Ansible into the host instead,
# to run `pct exec` itself, needs SSH to the hypervisor as root or nearly, and
# that is what the design of the API token set out to avoid; one stolen key
# would then reach every guest at once rather than one, and `pct exec` into the
# one privileged container is root on the host by another road.
#
# Run on the Proxmox host, once per container:
#
#   ./bootstrap-lxc.sh 101 "ssh-ed25519 AAAA... ansible@homelab"
#
# The key is the public half of `~/.ssh/homelab_ansible` in WSL2. It is not a
# secret, and it is not in this repository either, for the same reason the MAC
# addresses are not.
#
# Every step checks before it acts, so a second run changes nothing.
set -euo pipefail

VMID="${1:-}"
PUBKEY="${2:-}"
USERNAME=ansible

if [ -z "$VMID" ] || [ -z "$PUBKEY" ]; then
    echo "usage: $0 <vmid> \"<ssh public key>\"" >&2
    exit 2
fi

case "$PUBKEY" in
    ssh-*) ;;
    *) echo "the second argument does not look like an SSH public key" >&2; exit 2 ;;
esac

if [ "$(pct status "$VMID")" != "status: running" ]; then
    echo "container $VMID is not running" >&2
    exit 1
fi

inside() { pct exec "$VMID" -- "$@"; }
step() { printf '%-10s %s\n' "$1" "$2"; }
installed() { inside dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'ok installed'; }

# The SSH server, sudo, and the Python interpreter Ansible runs its modules
# through. The template ships none of the three.
missing=""
for pkg in openssh-server sudo python3; do
    installed "$pkg" || missing="$missing $pkg"
done

if [ -n "$missing" ]; then
    step packages "installing:$missing"
    inside apt-get update -qq
    # shellcheck disable=SC2086
    inside env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $missing
else
    step packages "openssh-server, sudo and python3 already there"
fi

# No password is ever set: the key is the only way in.
if inside id "$USERNAME" >/dev/null 2>&1; then
    step user "$USERNAME already exists"
else
    inside adduser --disabled-password --gecos "Ansible" "$USERNAME"
    step user "$USERNAME created"
fi

# Sudo without a password, for the same reason the k3s node has it: the roles
# install packages and write under /etc.
inside sh -c "printf '%s ALL=(ALL) NOPASSWD:ALL\n' '$USERNAME' > /etc/sudoers.d/$USERNAME"
inside chmod 0440 "/etc/sudoers.d/$USERNAME"
step sudo "/etc/sudoers.d/$USERNAME written"

inside install -d -m 700 -o "$USERNAME" -g "$USERNAME" "/home/$USERNAME/.ssh"
inside sh -c "printf '%s\n' '$PUBKEY' > /home/$USERNAME/.ssh/authorized_keys"
inside chown "$USERNAME:$USERNAME" "/home/$USERNAME/.ssh/authorized_keys"
inside chmod 600 "/home/$USERNAME/.ssh/authorized_keys"
step key "one key in authorized_keys"

# Keys only, and no root at all. Tested before the service is restarted, so a
# bad line never takes the server down.
inside install -d -m 755 /etc/ssh/sshd_config.d
inside sh -c 'printf "PasswordAuthentication no\nPermitRootLogin no\nKbdInteractiveAuthentication no\n" > /etc/ssh/sshd_config.d/10-homelab.conf'
inside sshd -t
inside systemctl enable ssh >/dev/null 2>&1 || true
inside systemctl restart ssh
step sshd "keys only, root refused, service $(inside systemctl is-active ssh)"

# Printed so the inventory can be written from what the container says, rather
# than from memory.
step address "$(inside sh -c "ip -4 -brief addr show scope global | awk '{print \$3}' | cut -d/ -f1 | tr '\n' ' '")"
