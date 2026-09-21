#!/bin/bash
# Open the door Ansible uses, in the development VM, in one command.
#
# The sibling of bootstrap-lxc.sh, for the machine that is not a container. The
# six containers came from a template with no SSH server and the door was opened
# from the host with `pct exec`. A VM has no `pct exec`, and the QEMU guest agent
# is not installed yet either, so this runs once at the Proxmox console:
#
#   curl -fsSL https://raw.githubusercontent.com/RuiGRMargarido/homelab/master/infra/ansible/bootstrap-mint.sh | sudo bash -s -- "ssh-ed25519 AAAA... ansible@homelab"
#
# The public key is pasted through the noVNC clipboard. It is not a secret, and
# it is not in this repository either, for the same reason the MAC addresses are
# not.
#
# Yes, this is a `curl | bash`, which this project refuses for other people's
# software. The difference is whose file it is: this one lives in this public
# repository, can be read before it is run (`curl ... | less`), and replaces
# eight commands typed by hand at a console. Installing a third party product
# that way buys nothing comparable.
#
# What it does, in order, because the order matters: the address first, since
# everything after it needs the network; then the SSH server; then the user, the
# key and sudo; then the keyboard. Every step checks before it acts, so a second
# run changes nothing and, in particular, does not drop the network under an SSH
# session that is using it.
set -euo pipefail

PUBKEY="${1:-}"
USERNAME=ansible

# Written out rather than discovered. This machine is in the Trusted zone and
# its address is a decision recorded in docs/NETWORK.md, not something a DHCP
# server here is trusted to keep (the lesson of 31/07/2026).
IPV4=10.10.20.12/24
GATEWAY=10.10.20.1
DNS=10.10.20.1
KEYMAP=es

if [ "$(id -u)" -ne 0 ]; then
    echo "run me with sudo" >&2
    exit 2
fi

if [ -z "$PUBKEY" ]; then
    echo "usage: $0 \"<ssh public key>\"" >&2
    exit 2
fi

# Checked in three parts rather than by its prefix alone. On 21/09/2026 the
# example key from the documentation was pasted by mistake into three
# containers: it starts with `ssh-`, so a prefix check let it through, it was
# written to `authorized_keys`, and those three refused every login afterwards
# with "Permission denied (publickey)".
keytype=${PUBKEY%% *}
keybody=${PUBKEY#* }
keybody=${keybody%% *}

case "$keytype" in
    ssh-ed25519 | ssh-rsa | ecdsa-sha2-*) ;;
    *) echo "not an SSH public key type: '$keytype'" >&2; exit 2 ;;
esac

case "$keybody" in
    *[!A-Za-z0-9+/=]*) echo "the key itself is not base64: did you paste the example instead of your key?" >&2; exit 2 ;;
esac

if [ "${#keybody}" -lt 60 ]; then
    echo "the key itself is only ${#keybody} characters: did you paste the example instead of your key?" >&2
    exit 2
fi

step() { printf '%-10s %s\n' "$1" "$2"; }

# The wired connection NetworkManager already has, found rather than assumed:
# the name is usually "Wired connection 1" and there is no rule that says so.
device=$(nmcli -t -f DEVICE,TYPE device status | awk -F: '$2 == "ethernet" { print $1; exit }')
if [ -z "$device" ]; then
    echo "no ethernet device found" >&2
    exit 1
fi

connection=$(nmcli -t -f NAME,DEVICE connection show --active | awk -F: -v d="$device" '$2 == d { print $1; exit }')
if [ -z "$connection" ]; then
    connection=$(nmcli -t -f NAME,DEVICE connection show | awk -F: -v d="$device" '$2 == d { print $1; exit }')
fi
if [ -z "$connection" ]; then
    connection=homelab
    nmcli connection add type ethernet ifname "$device" con-name "$connection" >/dev/null
fi

# Only touched when it is not already what it should be. `nmcli connection up`
# re-activates the interface, which would cut a later run of this script that
# arrived over SSH.
current_address=$(nmcli -g ipv4.addresses connection show "$connection")
current_method=$(nmcli -g ipv4.method connection show "$connection")
if [ "$current_address" = "$IPV4" ] && [ "$current_method" = "manual" ]; then
    step address "$IPV4 already set on $connection"
else
    nmcli connection modify "$connection" \
        ipv4.addresses "$IPV4" \
        ipv4.gateway "$GATEWAY" \
        ipv4.dns "$DNS" \
        ipv4.method manual
    nmcli connection up "$connection" >/dev/null
    step address "$IPV4 set on $connection"
fi

installed() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'ok installed'; }

# The SSH server, and the two Mint already has, listed for the same reason the
# container script lists them: so that the requirement is written down.
missing=""
for pkg in openssh-server sudo python3; do
    installed "$pkg" || missing="$missing $pkg"
done

if [ -n "$missing" ]; then
    step packages "installing:$missing"
    # The lock timeout is for the minutes after an installation, when the Mint
    # update manager is holding apt and the only symptom is a cryptic failure.
    apt-get -o DPkg::Lock::Timeout=180 update -qq
    # shellcheck disable=SC2086
    DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=180 install -y -qq $missing
else
    step packages "openssh-server, sudo and python3 already there"
fi

# No password is ever set: the key is the only way in. This is not the account
# the Mint installer created, which keeps its own password and its desktop.
if id "$USERNAME" >/dev/null 2>&1; then
    step user "$USERNAME already exists"
else
    adduser --disabled-password --gecos "Ansible" "$USERNAME" >/dev/null
    step user "$USERNAME created"
fi

# Sudo without a password, for the same reason every other guest has it: the
# roles install packages and write under /etc.
printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$USERNAME" > "/etc/sudoers.d/$USERNAME"
chmod 0440 "/etc/sudoers.d/$USERNAME"
step sudo "/etc/sudoers.d/$USERNAME written"

install -d -m 700 -o "$USERNAME" -g "$USERNAME" "/home/$USERNAME/.ssh"
printf '%s\n' "$PUBKEY" > "/home/$USERNAME/.ssh/authorized_keys"
chown "$USERNAME:$USERNAME" "/home/$USERNAME/.ssh/authorized_keys"
chmod 600 "/home/$USERNAME/.ssh/authorized_keys"
step key "one key in authorized_keys"

# Keys only, and no root at all. Tested before the service is restarted, so a
# bad line never takes the server down.
install -d -m 755 /etc/ssh/sshd_config.d
printf 'PasswordAuthentication no\nPermitRootLogin no\nKbdInteractiveAuthentication no\n' > /etc/ssh/sshd_config.d/10-homelab.conf
sshd -t
systemctl enable ssh >/dev/null 2>&1 || true
systemctl restart ssh
step sshd "keys only, root refused, service $(systemctl is-active ssh)"

# The keyboard the console and the desktop use. The installer already asked, and
# this is here so that the answer exists in code as well: the Ansible role sets
# the same value, and between the two there is no version of this machine whose
# layout depends on someone having remembered.
if grep -q "^XKBLAYOUT=\"$KEYMAP\"" /etc/default/keyboard; then
    step keyboard "already $KEYMAP"
else
    sed -i "s/^XKBLAYOUT=.*/XKBLAYOUT=\"$KEYMAP\"/" /etc/default/keyboard
    setupcon --save 2>/dev/null || true
    step keyboard "set to $KEYMAP"
fi

# Printed so the inventory is written from what the machine says rather than
# from memory.
step address "$(ip -4 -brief addr show scope global | awk '{print $3}' | cut -d/ -f1 | tr '\n' ' ')"
