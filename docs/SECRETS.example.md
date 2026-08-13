# Secrets and Access (template)

This file is the template, versioned in the repo, with no real values in it. The version holding the actual values is `docs/SECRETS.md`, which exists only locally (it is in `.gitignore` and is never committed).

If you are setting this project up fresh (new machine, or starting from scratch): copy this file to `docs/SECRETS.md` and fill in the real values there.

For important passwords and tokens, the better place is a password manager (Bitwarden, KeePassXC, etc.), either as well as or instead of this file. This one is for quick reference and for the fields that are not secrets in themselves (URLs, paths, usernames).

## Index

- [Base infrastructure](#base-infrastructure)
- [VMs and Containers (Proxmox)](#vms-and-containers-proxmox---includes-dhcp-reservations)
- [Administrative access per service](#administrative-access-per-service)
- [Service with multiple users (template)](#name-of-a-service-with-multiple-users-or-its-own-configuration-eg-truenas-nextcloud-jellyfin)
- [WireGuard](#wireguard)
- [Dynamic DNS](#dynamic-dns-access-from-outside-the-house)
- [API tokens and keys](#api-tokens-and-keys)
- [Key files](#key-files-never-inline-the-contents-here-only-the-path)
- [Datasets and important paths](#datasets-and-important-paths)
- [History](#history)

## Base infrastructure

| Service | URL / address | Username | Password |
|---|---|---|---|
| Proxmox VE | https://\<optiplex-ip\>:8006 | root@pam (or the dedicated user from Phase 4) | *(see password manager)* |
| Router | http://\<router-ip\> | | |
| Switch | http://\<switch-ip\> | | |

## VMs and Containers (Proxmox) - includes DHCP reservations

Practice: every server and VM has a static IP configured locally (`/etc/network/interfaces`), plus a DHCP reservation on the router as documentation and consistency (never rely on dynamic DHCP alone - the lease can expire without renewing itself).

Practice for containers: always `ip6=manual`, never `ip6=dhcp` (the default when creating one). With `dhcp`, the container waits five minutes for a DHCPv6 server that does not exist on this network before the console becomes usable.

| ID | Name | Type | IP | MAC | Reservation done? | Notes |
|---|---|---|---|---|---|---|
| | | VM/LXC | | | | |

## Administrative access per service

Central table with one main access per service. For services with more than one account, the last column links to the full list in that service's own section (see the example below).

| Service | Access | Username (main) | Password | All accounts |
|---|---|---|---|---|
| \<Service with a single account\> | | | | - |
| \<Service with several accounts\> | | | | [Accounts →](#user-accounts-service-name) |
| Firewall VM (OPNsense/pfSense) | https://\<firewall-vm-ip\> | | | - |
| Uptime Kuma | http://\<ip\>:3001 | | | - |
| k3s (kubectl) | *(see kubeconfig, path below)* | | | - |
| GitHub | github.com/\<user\>/\<repo\> | | *(handled by Git Credential Manager, no need to keep it here)* | - |

## \<Name of a service with multiple users or its own configuration\> (e.g. TrueNAS, Nextcloud, Jellyfin)

Create a section like this for every service that has more than one user, or enough configuration to justify its own section (follow the WireGuard pattern below). Simple services (just a root console) stay only in the generic "Administrative access per service" table.

| Field | Value |
|---|---|
| Where it runs | |
| Access | |

### User accounts (Service Name)

Include the service name in the heading (e.g. "User accounts (Nextcloud)"), so the link from the central table does not depend on the order of sections in the document.

| Username | Password | Notes |
|---|---|---|
| | | |

## WireGuard

| Field | Value |
|---|---|
| Where it runs | |
| Port | |
| Tunnel network | |
| Server IP inside the tunnel | |
| Endpoint for clients | |
| Server public key (not secret) | |
| Server private key | *(path on the server, never paste it here)* |
| Client configs (peers) | *(path)* |
| Port forward on the router | |

### Peers (clients)

| Name | Tunnel IP | File on the server |
|---|---|---|

## Dynamic DNS (access from outside the house)

| Field | Value |
|---|---|
| Provider | \<No-IP / DuckDNS / Dynu / other\> |
| Hostname | |
| Plan | |
| Account login | |
| Notes | *(e.g. free plans often require periodic hostname confirmation)* |

## API tokens and keys

| What | What it is for | Where it is / value |
|---|---|---|
| Proxmox API token (OpenTofu) | Phase 4 - lets OpenTofu create and manage VMs without using root@pam | |
| Slack Incoming Webhook | Alerts to #homelab-alerts | *(treat as a password - it is a bearer token)* |
| Healthchecks.io (if applicable) | Pings from scheduled jobs | |

## Key files (never inline the contents here, only the path)

| What | Path |
|---|---|
| SSH key used by Ansible | |
| k3s kubeconfig | |
| `infra/secrets/*.tfvars` (OpenTofu) | `<repo>\infra\secrets\` (gitignored, see Phase 4) |

## Datasets and important paths

| What | Path |
|---|---|
| TrueNAS datasets | |
| Backup mount point (external SSD) | |
| Passthrough disk(s) - `by-id` path | |
| Homelab repo (on this PC) | |
| Homelab repo (on the OptiPlex, if applicable) | |

## History

- 29/07/2026: created this template and the matching `docs/SECRETS.md` (local, gitignored).
- 29/07/2026: restructured to follow the reorganisation of `SECRETS.md` (separate sections for VMs/containers, access per service, dynamic DNS, WireGuard).
- 31/07/2026: restructured again - static IP practice (not DHCP alone) for VMs and LXCs; services with several users now get their own section with a "User accounts" sub-table (the WireGuard "Peers" pattern), instead of repeated rows in the generic table.
- 01/08/2026: "Administrative access per service" became the central table again (one row per service), right after "VMs and Containers", with an "All accounts" column linking to each service's sub-table. The "### User accounts" headings now include the service name in brackets.
- 11/08/2026: translated to English; added the `ip6=manual` practice for new containers.
