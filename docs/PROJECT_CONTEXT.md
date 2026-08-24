# Project Context: HomeLab

Living context document for the project. Update it whenever there are new decisions.

## Snapshot (19/02/2026, updated 12/08/2026)
- Goal: learn and deploy projects on a homelab with controlled external exposure (1-2 apps).
- Decided: Proxmox VE + TrueNAS (VM) + Caddy + WireGuard + Nextcloud + Jellyfin.
- **Phase 1 (base services) complete and validated** - all of the above running, plus automated backups with a tested restore.
- **Phase 2 (VLANs + firewall) in progress** - VLANs 10/20/30 active, OPNsense (VM 106) mediating the zones, WireGuard in the DMZ, Proxmox with an interface in Management, and TrueNAS migrated to Trusted (11/08/2026). Nextcloud and Jellyfin remain on the flat network; Caddy has been deferred (see History, 11/08/2026).
- **Media automation stack added (12/08/2026)**: LXC 107 with qBittorrent, Sonarr, Radarr, Prowlarr and Jellyseerr, with all download traffic routed through a commercial VPN via gluetun.
- Current storage: 1x 1TB HDD (3.5", in a TooQ USB bay, ZFS pool `tank_test` imported from the old NAS) + 1x 240GB SSD (Proxmox); plus a 1TB external SSD, formatted exFAT, used as the daily backup target.
- Current RAM: 16GB (the 32GB upgrade is still pending). See "Risks and mitigations" - the total already *configured* across VMs and LXCs exceeds the 16GB physically present.
- Network: VLAN + dedicated firewall architecture decided (22/07/2026) - see "Network and Segmentation". The TL-SG608E switch is managed, with 802.1Q VLAN support.
- Build order (decided 29/07/2026): base services first (simple network), VLANs and dedicated firewall afterwards - see "Build order".
- Development VM (28/07/2026, confirmed 02/08/2026): VM 100 `mnt-mate` (Linux Mint), for programming and testing agents/LLMs - network zone still undecided, see "Development environment" and Open items.

## History: v1 (old PC) vs v2 (OptiPlex, current)
- **v1 (old PC)**: the first version of the homelab, already running TrueNAS, Jellyfin and WireGuard (its own DDNS, Jellyfin reachable locally and remotely over WireGuard). There was also an AI/RAG stack in Docker (Open WebUI + Ollama + Qdrant) running on v1.
- **v2 (Dell OptiPlex 3060 Micro, in progress)**: the new homelab, replacing v1. Current state: Proxmox VE, TrueNAS (VM 102), WireGuard (LXC 103), Caddy (LXC 101), Nextcloud (LXC 104), Jellyfin (LXC 105), the OPNsense firewall VM (106), the development VM `mnt-mate` (100) and the media automation stack (LXC 107), all **created and running**. The v1 RAG stack (Open WebUI + Ollama + Qdrant) **has not been recreated** - whether it returns is still open, see Open items.

## Goals
- Build a homelab with controlled costs and low power draw and noise.
- Have a NAS, media server, personal cloud, VPN and reverse proxy.
- Allow for future growth (especially storage/RAID, services and security).
- Development environment: a Linux VM for programming and testing agents/LLMs (28/07/2026).

## Scope
- Included: base hardware, phased services, secure external exposure, an evolution plan, and a network architecture with VLANs and a dedicated firewall (decided 22/07/2026 - see "Network and Segmentation").
- Not included (for now): more zones or VLANs beyond the three defined (DMZ/Trusted/Management); high availability (multi-host); Wi-Fi/guest/IoT segmentation of the general household network (28/07/2026: decided to keep this independent of the OptiPlex, see "Home router and household network").

## Services (Phase 1)
- NAS: TrueNAS (VM) with ZFS. Zone: Trusted (migrated 11/08/2026).
- VPN: WireGuard for remote administration - the entry point into the internal zones from the internet. Zone: DMZ (the internet-facing leg); it assigns IPs to authenticated clients on a subnet of its own (the tunnel).
- Reverse proxy: Caddy - **deferred** (11/08/2026). Without local DNS names it provides no service, and in fact has provided none since July: it has been running with the default configuration and not a single proxy rule. It returns when there are local names with internal HTTPS, or when there is a decided app for public exposure.
- Cloud: Nextcloud - decided (22/07/2026) to stay internal only, with no public exposure; access exclusively over WireGuard. Zone: Trusted (pending migration).
- Media: Jellyfin - same pattern as v1 (remote access only over WireGuard). Zone: Trusted (pending migration). Hardware transcoding via Intel QuickSync enabled 12/08/2026.

## Architecture (high level)
- The current router handles DDNS; the port forward (80/443 once there is an exposed app; the WireGuard UDP port) points at the firewall VM's WAN-side leg, not directly at the services.
- A single host running Proxmox VE on the SSD (240GB).
- A dedicated firewall VM (OPNsense) mediates all traffic between zones - see "Network and Segmentation (VLANs + Firewall)".
- TrueNAS in a VM with dedicated disk(s) (Trusted zone). Datasets: the old v1 structure was kept (`media`, `backups`, `jellyfin_config`, `ISO`, `projects`, `shares`) rather than creating `apps`/`cloud`/`media`/`backups` from scratch - decided 29/07/2026 while importing the `tank_test` pool. Detail in `docs/CHECKLIST.md` §Phase 1.
- Apps in VMs and LXCs (or, later, k3s workloads) with data persisted on TrueNAS.
- **Practice (decided 29/07/2026, revised 31/07/2026): every homelab server and VM has a static IP configured locally** (`/etc/network/interfaces`), plus a DHCP reservation on the router for consistency and documentation. Revised after two LXCs lost their IPv4 when the lease expired without renewing itself - incident detail in `docs/CHECKLIST.md` §Phase 1. See `docs/SECRETS.md` §VMs and Containers for the list.
- Remote administration over WireGuard; avoid exposing admin interfaces to the internet.

## Build order

**Decided 29/07/2026.** The target architecture (above) includes VLANs and a dedicated firewall from the start, but the **build order** does not follow that same sequence: the base services (TrueNAS, WireGuard, Caddy, Nextcloud, Jellyfin) are built first, on a simple network with no VLANs (the same home network) - only then does the network segmentation arrive (VLANs + dedicated firewall), with the existing services migrated into the right zones.

**Reason**: building the dedicated firewall VM and the VLANs (the newest and least familiar part of the project) before any real service existed meant risking being blocked right at the start, with nothing to show, and with no real data or services for that segmentation to protect yet. On top of that, RAM is still 16GB (the 32GB upgrade is still pending) - the base services fit comfortably in 16GB; it is the dedicated firewall, VLANs and k3s that need the extra headroom. Doing the services first allows real progress on the hardware available today.

This changes no architectural or technology decision (still OpenTofu, still k3s, still the VLAN design described below) - it only changes the order in which the phases of `docs/CHECKLIST.md` are executed (Phase 1 = base services, Phase 2 = network and segmentation; before 29/07/2026 it was the reverse).

## Network and Segmentation (VLANs + Firewall)

**Decided 22/07/2026.** Replaces the earlier exclusion in Scope ("does not include a detailed network architecture"). The full design (diagram, VLAN table, NIC assignment, inter-zone rules) has a document of its own, easier to consult: **[`docs/NETWORK.md`](NETWORK.md)**.

Summary: 3 VLANs (10/DMZ, 20/Trusted, 30/Management) plus the WireGuard tunnel's virtual subnet, mediated by a **dedicated firewall VM** (OPNsense, not Proxmox's built-in firewall - chosen for being more capable, e.g. IDS/IPS; the concrete risks of this choice are in "Risks and mitigations": RAM, lockout, USB reliability, maintenance). Onboard NIC = trunk to the switch; USB→RJ45 adapter = the WAN leg. Open: which app actually goes into the DMZ zone - see "Open items". Nextcloud and Jellyfin are already decided as Trusted-only.

## Home router and household network (outside the homelab's segmentation, added 28/07/2026)

- **Model**: Vodafone Smart Router - Huawei OptiXstar HG8247B7-8N (ONT + GPON router supplied and locked down by Vodafone).
- **Guest network**: supported natively in the router's own interface - it can be enabled there directly, without depending on the OptiPlex or the homelab VLANs. This addresses the concern of guest devices losing network if the OptiPlex is restarted or switched off.
- **Custom 802.1Q VLANs** (e.g. to isolate IoT): not confirmed whether the router's interface exposes that option. Vodafone "Smart Router" units tend to ship with advanced features disabled by the operator.
- **Bridge mode: confirmed disabled by Vodafone** on this unit ([Vodafone forum](https://forum.vodafone.pt/t5/Router/Router-HG8247B7-8N-porta-4-de-2-5Gbps-s%C3%B3-d%C3%A1-100Mbps/m-p/448886)) - reinforcing the decision already taken that the router stays the real internet gateway, with the firewall VM not replacing it (that alternative would require bridge mode, which is not available without contacting Vodafone support, with no guarantee of being unlocked).
- **Static routes: confirmed unsupported** (11/08/2026). The router has custom DNS fields for DHCP clients but no static routing, which ruled out the cleanest way of giving household devices access to the Trusted zone - see History, 11/08/2026.
- **Scope decision**: additional Wi-Fi/guest/IoT segmentation of the general household network stays **independent of the OptiPlex** and outside the scope of the homelab VLANs (DMZ/Trusted/Management) - this avoids everyday devices (phones, laptops, guests, IoT) depending on the OptiPlex being available. If one day more segmentation is needed than the router allows natively, the way forward is an additional VLAN-capable access point or switch downstream of the router, not something integrated into the homelab firewall VM.

## Development and agent/LLM testing environment (added 28/07/2026)
- Goal: a dedicated Linux VM for programming and testing agents/LLMs.
- Models: a mix of local models (small/quantised, e.g. via Ollama) and calls to external APIs (Claude, OpenAI, etc.) - confirmed 28/07/2026 that it will be "probably both".
- **Hardware constraint**: the OptiPlex (i5-8500T) only has integrated graphics, no dedicated GPU - local inference is limited to small models and is slower (CPU-only), which is especially noticeable in agent loops (several consecutive model calls). Heavier or more frequent testing should prefer external APIs.
- **Network zone**: still undecided (28/07/2026) - Trusted (alongside TrueNAS/Nextcloud/etc., simpler) vs. an isolated zone of its own (safer, given that an agent with code execution and network access is a different risk profile from a Jellyfin or Nextcloud - it contains an agent behaving unexpectedly, e.g. through prompt injection, far better). See Open items.
- **RAM impact**: one more consumer added to an already tight budget (see Risks and mitigations). Confirm the real RAM ceiling of the OptiPlex 3060 Micro before assuming 32GB is enough, given this new requirement.

## Data (RAID vs backup)
- RAID (e.g. a ZFS mirror) protects against disk failure, but does not replace backups.
- Phase 1: no RAID (use the existing disks) + backups to a 1TB external SSD.
- Phase 3: buy 2x identical NAS HDDs and migrate to a ZFS mirror (RAID1).

## RAID with a mini PC (practical options)
- Best (most robust): move storage to a host with internal SATA disks (a tower) or use a dedicated NAS.
- If staying on the mini PC: use a powered 2-bay/4-bay DAS with a good USB controller (avoid RAID/ZFS in cheap USB enclosures).
- Avoid: building ZFS/RAID on unstable USB disks; USB is acceptable for backups, but RAID needs decent hardware and reliable cabling and power.

## Cost estimate (reference)
- 2-bay DAS (e.g. QNAP TR-002) + 2x 6TB NAS HDDs:
  - TR-002: ~EUR 174.
  - 2x 6TB: ~EUR 350 (depending on model).
  - Expected total: ~EUR 525 (excluding shipping).
- Dedicated 2-bay NAS (e.g. Synology DS223) + 2x 6TB NAS HDDs:
  - DS223 (diskless): ~EUR 279.
  - 2x 6TB: ~EUR 350 (depending on model).
  - Expected total: ~EUR 630.

## Decision: backups instead of RAID (to minimise cost)
- Chosen option: do not implement RAID for now; use backups (with at least two copies) to reduce cost.
- Practical recommendation:
  - 1x external SSD (1TB) for a "fast backup" of critical data.
  - 1x large external HDD (8TB+) for full backups.
  - Optional (safer): a second large external HDD for rotation/offsite.

## Backup (recommended hardware and costs)
- Option A (simplest, usually cheapest): 1-2x ready-to-use desktop external HDD (3.5").
  - Example: WD Elements Desktop 8TB: ~EUR 194 (EU reference price, 19/02/2026).
- Option B (internal HDD + powered USB enclosure): good if you want to choose the disk model.
  - Example: Toshiba N300 6TB + a powered USB-SATA adapter:
    - N300 6TB: ~EUR 204.50.
    - UGREEN USB 3.0 <-> SATA + 12V/2A adapter: ~EUR 20.79.
    - Total: ~EUR 225.29 (one disk).

## Links (examples)
- WD Elements Desktop 8TB: https://www.pcmadrid.es/discos-duros/215070-wd-elements-8tb-usb-30-negro.html
- Toshiba N300 6TB: https://www.pccomponentes.pt/toshiba-nas-n300-35-6tb-sata-3
- UGREEN USB <-> SATA + 12V/2A: https://www.amazon.es/dp/B00MYU0EAU
- Inateck FE3002 (powered 3.5" enclosure): https://www.idealo.de/preisvergleich/OffersOfProduct/202541873_-fe3002-inateck.html

## How the disks are used (backup vs primary)
- Disk A: primary storage (the "live" data on the NAS).
- Disk B: backup target (scheduled copies of Disk A).
- Good practice: rotation/offsite (e.g. unplug and store Disk B after the backup) to reduce the risk of ransomware or human error.
- Backups should have history and retention (versioning), and restores should be tested periodically.

## Hardware (requirements)
- Preference: a tower/MT with 2+ 3.5" bays and several SATA ports (for RAID and expansion).
- CPU: Intel with VT-x (ideally with VT-d); an 8th-gen i7 is a good balance for Proxmox.
- RAM: 32GB (TrueNAS + apps) with room to upgrade.
- Noise and power: prioritise an efficient PSU and quiet fans.

## Hardware (shortlist and prices)
- Refurbished (candidate): HP EliteDesk 800 G5 MT (i7-8700, 32GB, 500GB NVMe), Infocomputer Portugal (19/02/2026).
  - Confirm: 3.5" bays, free SATA ports, and whether caddies and SATA cables are included.
- Refurbished (good value): Lenovo ThinkCentre M720T MT (i7-8700, 32GB, 500GB NVMe) at ~EUR 339.85 (Infocomputer Portugal, 19/02/2026).
- Refurbished (alternative): HP EliteDesk 800 G4 (i7-8700, 32GB, 512GB SSD) at ~EUR 419.00 (Worten PT, 19/02/2026).
- Note: confirm availability and specifications (3.5" bays, SATA, PSU) before buying.

## Alternative option: mini PC (no internal RAID)
- If the priority is low power and noise, and internal RAID is not an immediate requirement, a mini PC can be enough.
- Limits: less room for 3.5" disks; additional storage tends to be an internal SSD (if there is a slot) or USB/DAS.
- Examples and links in `docs/HARDWARE.md`.

## Budget and phased purchases

Note: this section is about **purchases**, and the numbering below is independent of the phase numbering in `docs/CHECKLIST.md` (which organises work, not spending). The firewall and VLANs, for example, cost nothing in new hardware - they used the switch and USB adapter that already existed.

- Purchase 1 (done, 19/02/2026): the host only (EUR 229); existing HDD/SSD reused; an existing external SSD used for backups.
- Purchase 2 (pending, no date): 32GB of RAM - already the most urgent prerequisite, see "Risks and mitigations".
- Purchase 3 (pending): 2x identical NAS HDDs (4TB or 6TB) for the ZFS mirror; keep backups alongside the RAID.
- Purchase 4 (eventual): a larger SSD (512GB/1TB) for the host, once local storage gets tight.

## Installation plan (summary)
The full, up-to-date sequence (by phase, with done/pending status) lives in `docs/CHECKLIST.md`. Note: an earlier version of this summary (7 steps, with no firewall/VLANs/k3s) fell out of date against the decisions of 22-29/07/2026 and was replaced by this pointer to stop the two versions diverging again.

## Risks and mitigations
- Insecure external exposure: use a reverse proxy + TLS + limited ports + admin over VPN.
- Data loss (no RAID): frequent backups + tested restores; migrate to RAID when possible.
- Limited growth: choose a host with bays and SATA ports; plan in phases.
- Insufficient RAM: **no longer theoretical** (confirmed 02/08/2026) - the sum of what is *configured* across all VMs and LXCs exceeds the 16GB physically present. It only holds because *actual* usage stays below that, but there is no headroom for k3s or Prometheus/Grafana, and the development VM will grow with Docker and microservices. **Reinforced 12/08/2026** with the media automation stack, which added six containers and pushed the host into swap. Mitigation: treat the RAM upgrade as a real prerequisite for Phase 4 (not "when needed"); confirm whether 32GB is enough or whether the OptiPlex 3060 Micro supports more.
- Management lockout: if the firewall VM handles DHCP/DNS/routing for the internal VLANs, a failure in it can cut access to everything, including Proxmox itself. Mitigation: keep Proxmox management reachable from the WAN side, independent of the firewall VM's state; make network changes only with a local/noVNC console available, never purely remotely. **Validated in practice (06/08/2026)**: during the VLAN migration, the VPN became unreachable and so did Proxmox through the Management zone - the old flat-network IP (`192.168.1.206`) was the only path that kept working, and the entire diagnosis was done through it (including reaching the OPNsense GUI over an SSH tunnel). This reinforces the decision: **do not remove Proxmox's flat-network IP** while the firewall is the only route into Management.
- USB-RJ45 adapter reliability: it is consumer hardware, not server hardware (it can reset under sustained load). Mitigation: assigned to the WAN role (simpler and less critical), not to the internal VLAN trunk.
- Loss of the firewall configuration: more critical than losing "a service" - it is the entire network and security policy. Mitigation: export the firewall's own configuration (e.g. OPNsense's config.xml) in addition to the normal VM backup. **Still outstanding as of 12/08/2026.**
- **Circular dependency between hypervisor and guest** (added 10/08/2026): the Proxmox host mounts NFS from a VM it hosts itself. When that guest stalls, the host's I/O paths block, which can take down the management plane and prevent using the very tools (`qm`) that would bring the guest back. Mitigation: `soft` NFS mounts so a dead server returns errors instead of blocking indefinitely, plus `x-systemd.automount` so a failed mount retries instead of failing permanently. Validated twice, in opposite directions - see `docs/CHECKLIST.md`, 10/08 and 12/08.

- **The storage cannot sustain the write load asked of it** (added 24/08/2026, after a six-day incident). A single mechanical disk, in a USB dock, with no redundancy and no separate log device, serving NFS to five clients. It reads at 120 MB/s and writes 3GB locally at 91 MB/s, so it is not broken - but under NFS's synchronous commits it stalls, and when it stalls the failure does not degrade, it cascades: ZFS's `txg_sync` blocks, the `nfsd` threads block behind it, every client piles up in uninterruptible sleep, and the host's load average reaches the hundreds. Mitigations applied (see `CHECKLIST.md` Phase 2c) buy headroom without changing that fact. **This makes Phase 3 the highest-value item in the project**, ahead of Phase 4, and adds a requirement that was not in the original plan: a small SSD as a ZFS intent log, which is what would allow synchronous writes to return without the latency that caused the failures.
- **Firewall in the data path** (added 24/08/2026): migrating TrueNAS into the Trusted zone on 11/08 was correct for segmentation, but it also put every byte of storage traffic through a virtualised firewall. That was invisible until the firewall's emulated NICs turned out to cap throughput at 28 MB/s while burning both its cores. Fixed by switching to `virtio`, but the structural point stands: **a firewall that mediates services is one thing, a firewall that transports every disk block is another**, and the second needs to be sized and measured deliberately. If it becomes a constraint again, the alternative is a dedicated storage interface on the host, direct to VLAN 20.
- **Verification that does not verify** (added 24/08/2026): two separate checks during the incident returned "healthy" while the system was failing. `showmount -e` answered because `mountd` reads configuration, while `nfsd` was dead. And a `dd if=/dev/zero` throughput test passed at 54 MB/s without writing anything at all, because the dataset uses `lz4` and ZFS stores zero blocks as holes. Both sent the diagnosis in the wrong direction for hours. Mitigation, as a standing practice: **a check must exercise the thing it claims to prove** - test NFS with a real `ls`, test throughput with incompressible data, and verify a copy by comparing sizes rather than trusting the exit code.

## Open items
The full checklist with status (done/pending) for every task is in `docs/CHECKLIST.md`. Decisions still open (not tasks): which app goes into the DMZ zone (publicly exposed via Caddy) - Nextcloud and Jellyfin are already decided as Trusted-only, so the original goal of "exposing 1-2 apps" has no app attached until this is settled; the network zone for the development/LLM-agents VM (Trusted vs. an isolated zone of its own); confirming the real RAM ceiling of the OptiPlex 3060 Micro (32GB assumed); whether Healthchecks.io runs inside or outside k3s; whether to recreate the v1 RAG stack; and the fate of the old PC (v1) once v2 is operational.

## Recent decisions
- 19/02/2026: host chosen and ordered: Dell OptiPlex 3060 Micro (i5-8500T, 16GB RAM, 256GB SSD) for EUR 229.
  - Reason: best value within budget, with low power draw and noise.
  - Upgrade plan: 32GB RAM when needed; a larger SSD (512GB/1TB) once storage gets tight.
- 18/07/2026: confirmed that Proxmox VE was already installed on the OptiPlex (v2); the remaining services (TrueNAS, Jellyfin, WireGuard) were still to be installed on this new machine.

## History
- 19/02/2026: initial context, services and phased plan created and consolidated.
- 19/02/2026: initial host decided (Dell OptiPlex 3060 Micro) and a plan defined for when the equipment arrived.
- (earlier, old PC): homelab v1 operational with TrueNAS + Jellyfin + WireGuard + a RAG stack (Open WebUI/Ollama/Qdrant) in Docker.
- 18/07/2026: reviewed a historical conversation about v1 (media/streaming/VPN) and confirmed that it describes v1, not the current state of v2. Docs updated to reflect that v2 had, at that point, only Proxmox installed.
- 18/07/2026: tooling and good-practice plan decided for v2 (see `docs/TOOLING.md`): Obsidian (vault = this repo, synced over Git, no paid Obsidian Sync) for documentation; self-hosted Uptime Kuma + Healthchecks.io with Slack alerts for monitoring; adoption of IaC (OpenTofu + Ansible) right away.
- 22/07/2026: tooling plan revised to prioritise the practices that most represent modern infrastructure. Three changes: (1) application services move to a k3s (Kubernetes) cluster instead of one LXC/VM per service, entering early while the cost of redoing things is still low; (2) Prometheus+Grafana stop being "later" and enter the initial phase, because "is it up?" does not answer "why is it slow" nor detect gradual degradation; (3) a GitHub Actions workflow validating the IaC (tofu fmt/validate, ansible-lint, helm lint) before any real apply, given that a malformed apply does not fail a test, it destroys a VM. OpenTofu kept (not Terraform) - see the rationale in section 4 of the plan.
- 22/07/2026: created `docs/CHECKLIST.md` as the single operational document holding the done/pending status of every task, consolidating what was scattered across "Next steps" (README.md), "Open items" (this file) and the "Recommended execution order" in the tooling plan. This file (PROJECT_CONTEXT.md) remains the decision and context log; CHECKLIST.md is only task status.
- 22/07/2026: hardware review. Confirmed that the 1TB HDD (TooQ USB bay) was visible but with the old NAS's ZFS pool not yet imported - not a hardware problem, it just needed the TrueNAS VM + passthrough + "Import pool". Also confirmed additional network hardware (TP-Link USB→RJ45 adapter + TL-SG608E switch) - final topology not yet decided.
- 22/07/2026: correction - the TL-SG608E had been recorded incorrectly as "unmanaged, no VLANs". Confirmed via the official TP-Link datasheet that it is a managed Easy Smart Switch with 802.1Q VLAN support (port-based, tag-based, MTU VLAN), QoS, IGMP Snooping and LACP. It was chosen precisely for this.
- 22/07/2026: the complete network architecture decided (replacing the earlier exclusion in Scope). VLANs: 10/DMZ (WireGuard), 20/Trusted (TrueNAS, Caddy, Nextcloud, Jellyfin, k3s), 30/Management (Proxmox, switch); the WireGuard tunnel subnet (10.10.40.0/24) is virtual, not a switch VLAN. Onboard NIC = trunk to the switch; USB→RJ45 adapter = WAN leg. A dedicated firewall VM decided (OPNsense/pfSense), not Proxmox's built-in firewall - the risks (RAM, lockout, USB reliability, config backup) recorded in "Risks and mitigations". Nextcloud and Jellyfin decided as Trusted-only (access over WireGuard only, no public exposure) - which app goes into the DMZ remains open.
- 28/07/2026: new requirement - a Linux VM for programming and testing agents/LLMs, with a mix of local models and external APIs. Hardware with no dedicated GPU (integrated graphics only) limits local inference to small, slow models. The network zone (Trusted vs. isolated) is left open. This reinforces the RAM risk already recorded.
- 28/07/2026: home router identified - Vodafone Smart Router (Huawei OptiXstar HG8247B7-8N). Confirmed: guest network supported natively (independent of the OptiPlex); bridge mode disabled by Vodafone (reinforcing the decision not to replace the router with the firewall VM as gateway); custom 802.1Q VLANs not confirmed in the router's interface. Decided to keep Wi-Fi/guest/IoT segmentation outside the scope of the homelab VLANs and independent of the OptiPlex.
- 29/07/2026: created `docs/NETWORK.md` as a reference document of its own for the network architecture (diagram, VLAN table, NIC assignment, inter-zone rules), easier to consult than scrolling through the decision log. The "Network and Segmentation" section of this file was reduced to a pointer.
- 29/07/2026: full documentation audit. Corrected: "Installation plan (summary)" (7 outdated steps, with no firewall/VLANs/k3s) replaced by a pointer to CHECKLIST.md; README.md corrected (Caddy described as publicly exposed, with the port forward pointing directly at the reverse proxy - both out of date); WORKFLOW.md missing Caddy in its table and diagram; TOOLING.md not mentioning CHECKLIST.md or NETWORK.md in the recommended structure; two new open items added (RAM ceiling, where Healthchecks.io lives) for consistency between this file and CHECKLIST.md. Em dashes also replaced by plain hyphens across all documents - 114 occurrences.
- 29/07/2026: **build order decided** (new "Build order" section) - Phase 1 of CHECKLIST.md becomes base services (TrueNAS, WireGuard, Caddy, Nextcloud, Jellyfin, on a simple network with no VLANs), with Phase 2 (network and segmentation) coming afterwards, migrating the existing services into the right zones. It had been the reverse since 22/07/2026. Reason: avoid blocking the project's first real progress on its newest and most complex part (dedicated firewall + VLANs) before any service existed; confirmed that RAM is still 16GB, and the base services fit within that without needing the extra headroom the firewall and k3s require.
- 29/07/2026: **implementation actually began**. TrueNAS VM (102) created on Proxmox (6GB RAM, 4 cores, a 32GB disk for the OS), with the 1TB disk attached by `by-id` passthrough (not a new virtual disk). TrueNAS SCALE 25.10.5 installed on the 32GB disk; the v1 ZFS pool `tank_test` imported successfully, 0 errors, previous scrub healthy. Decided to keep the old dataset structure rather than creating a new one. Identified a `VM_ubuntu_wireguard-ulqfm6` zvol: the disk of a VM that used to run inside TrueNAS itself on v1 (TrueNAS SCALE has an embedded hypervisor) - not part of the v2 architecture (Proxmox is the only hypervisor), kept only as an archive until the new WireGuard is confirmed and it can be deleted. Created `docs/SECRETS.md` with the real access details for Proxmox and TrueNAS.
- 29/07/2026: confirmed the old PC (v1) is switched off. SMB shares created (`shares`, `media`, `backups`) and an NFS export (`media`) on TrueNAS, with a dedicated `rui` user (SMB access only). **The practice of a DHCP reservation on the router for every server and VM decided** (instead of dynamic DHCP) - first applied to TrueNAS.
- 31/07/2026: **Phase 1 complete** - Caddy (LXC 101), Nextcloud (LXC 104) and Jellyfin (LXC 105) created and validated. Nextcloud and Jellyfin run Docker Compose inside unprivileged LXCs (`nesting=1,keyctl=1`), with their data on TrueNAS over NFS mounted on the Proxmox host and passed to the containers as a bind mount - an unprivileged LXC cannot mount NFS directly. **Technical lesson**: NFS exports used by these containers need `Mapall` (not `Maproot`), because the "root" inside an unprivileged LXC with Docker on top never arrives at TrueNAS as a real UID 0.
- 31/07/2026: **addressing practice revised** - a DHCP reservation on the router is no longer sufficient on its own. After two LXCs lost their IPv4 when the lease expired without renewing, all four LXCs moved to a **static IP** configured locally, with the router reservation kept only as documentation.
- 02/08/2026: **automated backup, validated end to end** - a 1TB external SSD formatted exFAT (decision: it stays usable as an ordinary Windows disk, in exchange for losing TrueNAS's native Replication Tasks), with a daily `rsync` over cron copying the `nextcloud` and `shares` datasets. Restore tested at three levels (file listings, checksum, actually playing back a file). Also confirmed VM 100 `mnt-mate` (Linux Mint, 4 cores/8GB/64GB), which had been unidentified for weeks: it is the development and testing environment (VS Code + Docker, microservices).
- 06/08/2026: **Phase 2 began - the segmented network came into existence**. Trunk port configured on the switch, VLAN-aware bridge on Proxmox, the USB→RJ45 adapter as the WAN leg, and the dedicated firewall VM created (OPNsense, VM 106) with one interface per zone. WireGuard migrated to the DMZ (`10.10.10.10`) and the Proxmox host gained a second interface in Management (`10.10.30.2`), keeping the flat-network one. **Important design discovery**: the switch's trunk port also carries VLAN 1 untagged, meaning the switch is simultaneously the homelab trunk and an ordinary household switch - the home network does **not** pass through the dedicated firewall, only VLANs 10/20/30 do. This was not explicit in the original scheme and only surfaced while physically building Phase 2 (see `docs/NETWORK.md`).
- 06/08/2026: **an incident that validated the "management lockout" risk** already recorded in Risks - after the migration, the VPN became completely unreachable and so did Proxmox through Management. Real cause: the port-forward rule on the router still pointed at WireGuard's pre-migration IP. The diagnosis was only possible because Proxmox kept its old flat-network IP.
- 11/08/2026: **TrueNAS migrated to the Trusted zone** (`10.10.20.10`), the first service to leave the flat network and, with it, all of the homelab's data. Storage traffic now crosses the dedicated firewall. Also decided how household devices reach services in Trusted: **destination NAT on the OPNsense**, after confirming the router does not support static routes, and rejecting the option of pointing the whole household's DNS at the OptiPlex (it would make the family's browsing depend on it). **Caddy deferred** as a consequence: without local names it provides no service, and in fact had provided none since July.
- 12/08/2026: **media automation stack added** (LXC 107): qBittorrent, Sonarr, Radarr, Prowlarr and Jellyseerr, with all download traffic routed through a commercial VPN via gluetun (`network_mode: "service:gluetun"`, so the download client has no network of its own and cannot leak). Hardware transcoding enabled on Jellyfin via Intel QuickSync. **A serious incident followed**, where the TrueNAS NFS service stalled and took the whole host to a load average of 274 with nothing actually broken - see `docs/CHECKLIST.md` for the full write-up, which is the most instructive of the project.
- 24/08/2026: three risks added after the incident of 18-24/08 - the storage being unable to sustain the write load, the firewall having ended up in the data path, and checks that returned "healthy" while the system was failing. The last of these is the one worth carrying forward as a habit: during that week, `showmount` answered while `nfsd` was dead, and a `dd` throughput test passed at 54 MB/s without writing a single byte to disk. **Phase 3 was reprioritised above Phase 4** as a direct result.
