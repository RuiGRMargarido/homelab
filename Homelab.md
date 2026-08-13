---
tags: [homelab, moc]
---

# Homelab v2

Main note (MOC - *map of content*) for the project. Always start here.

## Status and decisions
- [Project context and history](docs/PROJECT_CONTEXT.md) - goal, architecture, current state and decisions.
- [Implementation checklist](docs/CHECKLIST.md) - status (done/pending) of every task, by phase.
- [Network reference](docs/NETWORK.md) - current vs target state, VLANs, component inventory, inter-zone rules and end-to-end packet paths.
- [Data and storage map](docs/STORAGE.md) - from the physical disk to the container: ZFS, NFS, bind mounts, backups and boot-order dependencies.
- [Hardware shortlist](docs/HARDWARE.md) - criteria and options considered for the host.
- `docs/SECRETS.md` - access details, tokens and paths. **Only exists on this machine** (gitignored, never on GitHub) - the link will not work on another device unless you copy the file across separately. Template with no real values: [SECRETS.example.md](docs/SECRETS.example.md).

## How to work on this project
- [Tooling, documentation, monitoring and IaC (plan)](docs/TOOLING.md) - Obsidian, Slack/Uptime Kuma/Healthchecks, OpenTofu/Ansible.
- [Architecture and workflow](docs/WORKFLOW.md) - a beginner-friendly explanation of where each tool lives and how it all fits together.

## Services
*(still empty - create one note per service under `docs/services/` once the first one is installed, e.g. TrueNAS)*

## Runbooks
*(still empty - create recovery procedures under `docs/runbooks/` as services become stable)*

## History
- 18/07/2026: created this main note, as the entry point into the Obsidian vault.
- 29/07/2026: added links to `docs/SECRETS.md` (local, gitignored) and its template `docs/SECRETS.example.md`.
- 11/08/2026: documentation translated to English and files renamed, as the project became part of a public portfolio.
