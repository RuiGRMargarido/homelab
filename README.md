# Homelab

A self-hosted infrastructure project built on a single refurbished mini PC: a VLAN-segmented network behind a dedicated firewall, running NAS, personal cloud, media streaming and VPN services, with automated and restore-tested backups.

Everything here is documented as it was actually built, including the parts that broke. The incident write-ups are the point, not an afterthought.

> Documentation is written in Portuguese. This README is the English entry point.

## Stack

| Layer | Technology |
|---|---|
| Hypervisor | Proxmox VE (VMs + LXC containers) |
| Firewall / routing | OPNsense (dedicated VM, 4 network zones) |
| Network | 802.1Q VLANs, VLAN-aware Linux bridges, managed switch trunk |
| Storage | TrueNAS SCALE, ZFS, NFS + SMB exports |
| VPN | WireGuard |
| Services | Nextcloud, Jellyfin, Caddy (all Docker Compose inside LXC) |
| Backups | `rsync` to external SSD, cron-scheduled, restore validated |
| Planned | OpenTofu, Ansible, k3s, Prometheus + Grafana, GitHub Actions CI |

Hardware: Dell OptiPlex 3060 Micro (i5-8500T, 16GB RAM), 1TB HDD, 1TB external SSD for backups, TP-Link TL-SG608E managed switch.

## Network architecture

Traffic between zones is mediated by a dedicated OPNsense VM. The home network reaches the internet directly, without crossing the firewall; only the homelab VLANs go through it.

![Network architecture](docs/diagrams/rede-arquitetura.svg)

| Zone | VLAN | Subnet | Contents |
|---|---|---|---|
| DMZ | 10 | `10.10.10.0/24` | WireGuard, the only service reachable from the internet |
| Trusted | 20 | `10.10.20.0/24` | TrueNAS, Caddy, Nextcloud, Jellyfin |
| Management | 30 | `10.10.30.0/24` | Proxmox web UI and API, switch management |
| VPN tunnel | - | `10.10.40.0/24` | Virtual subnet, assigned to authenticated clients |

**Note on the diagram above**: it shows the target state. The segmentation is built and working, but only WireGuard and the Proxmox management interface have been migrated so far. The remaining services are still on the flat network. The [network document](docs/ESQUEMA_LOGICO_REDE.md) tracks current state and target state as separate diagrams, deliberately, so the documentation never claims more than what exists.

## Current status

| Phase | State |
|---|---|
| 0. Hardware | Done, except a pending RAM upgrade to 32GB |
| 1. Base services | **Done** and validated (TrueNAS, WireGuard, Caddy, Nextcloud, Jellyfin, backups) |
| 2. VLANs and firewall | **In progress** (network built, service migration pending) |
| 3. Storage / RAID | Not started |
| 4. IaC and Kubernetes | Not started |
| 5. Monitoring and alerting | Not started |
| 6. Documentation tooling | Not started |

Full task-level breakdown in [CHECKLIST.md](docs/CHECKLIST.md).

## What this project demonstrates

**Network segmentation that actually exists.** Most homelabs are a flat network with containers on it. This one has 802.1Q VLANs trunked over a single physical link, a VLAN-aware bridge on the hypervisor, and a dedicated firewall VM with a default-deny policy between four zones.

**Backups that were restored, not just taken.** The restore was validated at three levels: structural comparison of file listings, checksum verification, and playing back an actual restored video file. A backup nobody has restored is a hypothesis.

**Failure analysis written down.** Every incident has a post-mortem covering the symptom, the diagnosis path, the root cause and the fix. Some of them document my own wrong turns, because the wrong turn is usually the useful part.

**Honest state tracking.** Documents separate what is built from what is planned. When a diagram described the intended architecture as if it were reality, that was treated as a defect and fixed.

## Selected engineering write-ups

These are the parts worth reading if you want to see how problems were approached, not just what was installed.

**[VPN completely unreachable after the VLAN migration](docs/CHECKLIST.md#histórico)** - symptom was a WireGuard client reporting a connection with zero bytes received. Diagnosis eliminated layers from the inside out: inter-zone firewall rules, then the container's own iptables (packet counters stayed at zero through a real VPN reconnect, proving handshake packets never even reached the DMZ), then the NAT rule, then DNS. Root cause was a port-forward rule on the home router still pointing at the service's pre-migration IP. The lesson recorded was about verifying persisted configuration rather than trusting an earlier edit.

**[NFS permissions through two layers of UID translation](docs/CHECKLIST.md#histórico)** - Nextcloud failed with `chown: Operation not permitted` against an NFS export. The cause was that "root" inside an unprivileged LXC running Docker never arrives at the NFS server as real UID 0, so `Maproot` does not apply and `Mapall` is required. The finding was applied preemptively to the next service, which worked first time.

**[Backup silently aborting on exFAT](docs/CHECKLIST.md#histórico)** - `rsync -a` failed the entire transfer because exFAT cannot store Unix ownership, and `-a` always tries to preserve it. Resolved with explicit flags matched to the filesystem's actual capabilities.

**[DHCP leases expiring without renewal](docs/CHECKLIST.md#histórico)** - containers lost IPv4 connectivity after hours of uptime. Two rounds of fixes treated the symptom before the actual cause was identified, leading to a project-wide move to static addressing.

## Documentation

| Document | Contents |
|---|---|
| [CHECKLIST.md](docs/CHECKLIST.md) | Task-level status per phase, plus the full incident log |
| [ESQUEMA_LOGICO_REDE.md](docs/ESQUEMA_LOGICO_REDE.md) | Network reference: current vs target state, physical topology, firewall rule matrix, end-to-end packet paths |
| [ESQUEMA_DADOS_E_STORAGE.md](docs/ESQUEMA_DADOS_E_STORAGE.md) | Storage chain from physical disk to container, boot-order dependencies, backup design |
| [PROJECT_CONTEXT.md](docs/PROJECT_CONTEXT.md) | Decision log with rationale, including reversed decisions |
| [PLANO_FERRAMENTAS_E_BOAS_PRATICAS.md](docs/PLANO_FERRAMENTAS_E_BOAS_PRATICAS.md) | Tooling decisions: IaC, monitoring, documentation |
| [ARQUITETURA_E_FLUXO_DE_TRABALHO.md](docs/ARQUITETURA_E_FLUXO_DE_TRABALHO.md) | Where each tool runs and how the workflow fits together |
| [HARDWARE_SHORTLIST.md](docs/HARDWARE_SHORTLIST.md) | Hardware criteria and options considered |

## A note on secrets

Credentials, keys and access details live in `docs/SEGREDOS.md`, which is gitignored and has never been committed. [SEGREDOS.example.md](docs/SEGREDOS.example.md) is the versioned template with the structure and no real values.

Hostnames, public addresses and personal identifiers have been redacted from the public documentation. Internal RFC 1918 addresses are kept because they carry no risk on their own and removing them would make the network documentation unreadable.
