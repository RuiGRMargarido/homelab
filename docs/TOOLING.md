# Plan: Tooling, Documentation and Good Practices (Homelab v2)

Decision document. Covers: which Claude Code skills and plugins to adopt, documentation management through Obsidian, monitoring with Slack alerts, and the adoption of Infrastructure as Code (IaC). Created on 18/07/2026, from research and decisions taken in that session. Revised on 22/07/2026 to prioritise the practices that most represent modern infrastructure (Kubernetes, observability, CI applied to IaC).

## 0. Decisions from that session
- **Obsidian**: already in use on another project. Staying on the free tier, no paid Obsidian Sync. Synchronisation over Git.
- **Monitoring**: self-hosted as soon as possible (Uptime Kuma + ~~Healthchecks.io~~ + Prometheus/Grafana from the start, not later on), alerting into Slack. *Healthchecks was dropped on 31/08/2026, see §3; the rest of this section records what was decided on 18/07 and is left as written.*
- **IaC**: adopt OpenTofu + Ansible right away, even this early into v2.
- **Kubernetes**: application services (Jellyfin, Nextcloud, monitoring) move to a **k3s** cluster, rather than one isolated LXC/VM per service - see section 4.
- **CI**: automatic IaC validation through GitHub Actions before any `apply` - see section 4.

**Why these three changes (22/07/2026):** the original plan solved the homelab but avoided the three practices that most distinguish modern infrastructure from "some VMs with services on them". Kubernetes was not in the plan at all, despite being the dominant model for running applications; Prometheus/Grafana had been deferred as "not urgent", when observability is precisely what lets you see what is happening before it breaks; and there was existing CI experience (GitHub Actions) that was not being applied to infrastructure, where a mistake costs far more than in a build.

## 1. Claude Code - skills and plugins to adopt

### Already available (nothing to install)
- `schedule` - for reminders and recurring tasks (e.g. a periodic homelab status digest).
- `loop` - for iterative working sessions (e.g. building the IaC playbook by playbook).
- `code-review` / `security-review` - **always use before applying** Terraform/Ansible changes that touch real infrastructure. This is the most important safety net when adopting IaC early.
- `verify` - confirm a service genuinely works end to end (not just that `terraform apply` or `ansible-playbook` exited without error).

### To install or configure
- **Slack (official)**: the `slackapi/slack-skills-plugin` plugin (Claude Code + Slack MCP Server, published on the official marketplace). Authentication via OAuth to the workspace. Lets Claude read and write in Slack directly - useful to complement the automated alerts with a natural-language summary, if wanted.
- **Terraform/OpenTofu (official, HashiCorp)**: "HashiCorp Agent Skills" - brings official Terraform/Packer knowledge, module validation and state inspection. Makes sense given IaC is being adopted now.
- **Obsidian MCP (through a plugin inside Obsidian itself)**: since v4.0 of the **Local REST API** plugin, the plugin exposes a built-in MCP server (no separate Python/uvx process needed any more) - roughly a five-minute setup. Gives Claude vault-aware operations (backlinks, tags, daily notes, graph search) beyond plain file editing. Optional for now: the vault is the repo folder itself, so Claude Code can already read and edit the `.md` files directly without it. Worth enabling once the vault grows and tags/backlinks start earning their keep.

### A note on "connectors"
Ready-made connectors (Slack, Obsidian) were searched for through Claude's "connectors" system - that system is not available or populated in this environment (Claude Code CLI). The correct integration here is configuring MCP servers manually (`claude mcp add ...`), not through the claude.ai connectors.

### Found but not recommended for blind installation
- `jmagar/claude-homelab` - a marketplace of agents and skills specific to homelab management (setup, health checks, status dashboard). It is a third-party project: if you want to try it, read the code first, particularly what it does with credentials, before granting it access to your homelab's tools.

## 2. Documentation - Obsidian

- **The vault is the repository folder itself.** Obsidian works over any folder of Markdown - nothing needs converting, the existing `.md` files work as they are.
- **Free synchronisation over Git**: install the community plugin **obsidian-git** inside Obsidian (Settings → Community plugins). It gives you a commit/push/pull button and can run scheduled auto-backups. That syncs between devices without paying for Obsidian Sync - you just need the repo cloned on each machine or phone. Note (11/08/2026): `.obsidian/plugins/` is now gitignored, so on a new device the plugin has to be installed by hand once before the sync works.
- **Recommended structure** (an evolution of what already exists, not a rewrite):
  - `Homelab.md` (root note / MOC - *Map of Content*) - replaces and expands the README as the entry point inside Obsidian, linking to the notes below.
  - `docs/services/` - one note per service (Proxmox, TrueNAS, Jellyfin, WireGuard, Uptime Kuma, OPNsense...), each with: current state, key configuration, link to the runbook.
  - `docs/runbooks/` - recovery procedures per service ("if X fails, do Y"). Important for disaster recovery - documenting is not only `PROJECT_CONTEXT.md`, it is also "how do I restore this at 2am".
  - `docs/PROJECT_CONTEXT.md` stays as it is - the history and recent decisions already follow the shape of a decision log, which is a good habit worth keeping.
  - `docs/CHECKLIST.md` (created 22/07/2026) - done/pending status of every task, by phase; `PROJECT_CONTEXT.md` stopped duplicating this.
  - `docs/NETWORK.md` (created 29/07/2026) - diagram and quick reference for the network architecture (VLANs, NICs, rules), separate from the decision log.
  - Suggested tags: `#pending`, `#decision`, `#risk`, `#service` - so you can navigate through Obsidian's graph rather than only through folders.

## 3. Monitoring and alerting - Slack

Three complementary levels, all self-hosted in the homelab itself, all alerting into a dedicated Slack channel (e.g. `#homelab-alerts`) through a Slack **Incoming Webhook** (simpler than OAuth for outbound alerts only):

1. **Uptime Kuma** - real-time "is it up?" monitoring (HTTP/TCP/ping/Docker/SSL) for each service (TrueNAS, Jellyfin, WireGuard, router...). Supports Slack natively (one of its 90+ notification channels). It is the de facto standard for homelabs.
2. ~~**Healthchecks.io (self-hosted)**~~ - **dropped 31/08/2026**, and the reasoning matters more than the conclusion.

   The need was real and remains: a *dead man's switch* for scheduled jobs (backups, ZFS scrub, Ansible runs). A script ends with a `curl` to a unique URL; if the ping never arrives, it alerts. It catches the failure Uptime Kuma structurally cannot see - "the backup stopped running three weeks ago but the server is up" - because a job that fails produces an error, while a job that stops running produces **nothing at all**, and silence is the only evidence.

   What changed is that **Uptime Kuma turned out to already implement this**. Its **Push** monitors are dead man's switches: the monitor waits for a heartbeat and goes red if none arrives within the interval. The mechanism the whole tool was chosen for is a monitor type in something already installed.

   **What Healthchecks would still add**: proper cron-expression schedules rather than a flat interval, per-check grace periods, and a richer history of job runs. Genuinely better *if there were many scheduled jobs with irregular timing*. There are two, both on fixed schedules.

   **What it would cost**: it is a Django application, so PostgreSQL, `SITE_ROOT` and allowed-hosts configuration, its own notification channel configured separately from the existing Slack webhook, and another container and database to maintain. On a host with 16GB that **ran out of memory on 25/08** (load 1633, 741MB available) and where the decision of 24/08 was to buy no more hardware, that is not a small addition.

   And it would contradict the rule written into `MONITORING.md` the same week: **whatever does the watching must be simpler, and depend on less, than what it watches.** Standing up a Django and Postgres stack to watch two cron jobs inverts that.

   **The decision**: cover the scheduled jobs with Uptime Kuma Push monitors, on the instance that already exists and is already wired to Slack. **Revisit Healthchecks if** the number of scheduled jobs grows beyond a handful, if any of them needs a genuine cron expression rather than a fixed interval, or if per-job grace periods start mattering. The need was never wrong; the second tool was.
3. **Prometheus + Grafana** - brought forward into the initial phase (it used to be "later, not urgent"). Rationale: the two levels above answer "is it up?", but not "why is it slow" nor "this has been degrading for weeks". On a host whose RAM is already overcommitted (see `PROJECT_CONTEXT.md` §Risks), knowing the consumption trend is worth more than a binary alert. Running it inside the k3s cluster (section 4) through `kube-prometheus-stack` (a Helm chart) is close to immediate - node/cAdvisor exporters plus ready-made dashboards, with no significant manual configuration, giving CPU/RAM/disk/network graphs per VM and per pod.

Optional complement through Claude: a scheduled task (the `schedule` skill) running, say, once a day, querying the Uptime Kuma API plus the open items in `PROJECT_CONTEXT.md`, and posting a natural-language summary into the same Slack channel. That is a *report*, not the critical alert - the alerting itself (steps 1 and 2) must keep working without depending on any LLM session running.

## 4. Infrastructure as Code

Chosen stack: **OpenTofu** with the **`bpg/proxmox`** provider (the most actively maintained) to provision VMs and LXCs; **Ansible** to configure them from the inside (packages, Docker, k3s, TrueNAS); **k3s** (lightweight Kubernetes) to run the application services instead of one LXC per service.

### Why OpenTofu and not Terraform

OpenTofu is used instead of HashiCorp's official Terraform for two reasons, though the skill being learned is the same:

- **Licensing**: in 2023 HashiCorp changed Terraform's licence from MPL (open source) to BSL (Business Source License), which restricts commercial uses that "compete" with HashiCorp products. The Linux Foundation, backed by dozens of companies (AWS, Oracle, Harness, Spacelift...), forked the last MPL code and created **OpenTofu** - which stays fully open source, under neutral governance rather than a single company's.
- **Full compatibility**: OpenTofu uses the same language (HCL), the same state format and the same providers from the Terraform registry (including `bpg/proxmox`). A `.tf` file written for OpenTofu runs on Terraform and vice versa - there is nothing "different" to learn. In practice `tofu` is just a different binary from `terraform`, with the same syntax, so the experience of writing HCL, managing state, providers and modules transfers one to one.

### Kubernetes (k3s) instead of one LXC per service

Rather than one Ansible-configured LXC/VM per service (`jellyfin`, `nextcloud`, `monitoring`...), the application services run as workloads on a **k3s** cluster - a lightweight Kubernetes distribution built for exactly this scenario (single node or a few nodes, modest hardware). TrueNAS stays a dedicated VM: running it bare, outside the cluster, makes sense because of the disk passthrough.

- **Provisioning**: OpenTofu creates the base VMs (e.g. 1-3 k3s nodes); Ansible installs k3s on them (a `k3s-server`/`k3s-agent` role, or the community `k3s-io/k3s-ansible` role).
- **Services**: each service (Jellyfin, Nextcloud, Uptime Kuma, Prometheus/Grafana) becomes a manifest or Helm chart under `infra/kubernetes/`, applied with `kubectl apply` or `helm install` - no longer its own Ansible role per service.
- **Why now and not later**: adopting Kubernetes after five services are already running in hand-built LXCs means migrating all of them, and every migration is a chance to break something that worked. Getting in early, while the cost of redoing things is still low, is cheaper than getting in late. The homelab is also the right place to get it wrong: a bad configuration here carries no production cost.

Proposed repo structure:
```
infra/
├── opentofu/         # provider config + VM definitions (incl. k3s nodes)
│   └── ...
├── ansible/
│   ├── inventory/
│   └── roles/        # truenas, k3s-server, k3s-agent, base...
├── kubernetes/
│   ├── truenas-storage/   # StorageClass / PVs bound to TrueNAS (NFS/iSCSI)
│   ├── jellyfin/          # manifests or Helm chart values.yaml
│   ├── nextcloud/
│   └── monitoring/        # kube-prometheus-stack (Prometheus+Grafana) + Uptime Kuma
└── secrets/           # never committed in plain text (see below)
```

**Secrets**: start simple - a `.gitignore` covering `*.tfvars`, `secrets/`, `*vault.yml`, `*values-secret.yaml`, keeping only `.example` files versioned as templates. Move to SOPS + age (encrypting secret files so they can be committed as ciphertext) when the volume justifies it - the extra complexity is not worth it on the first playbook.

**Proxmox**: create a dedicated user and role with minimum permissions, plus its own API token for OpenTofu to use - never `root@pam`.

**Discipline**: every infrastructure change goes through `code-review`/`security-review` before `tofu apply` / `ansible-playbook` / `kubectl apply`, and gets recorded in the `PROJECT_CONTEXT.md` history.

### The Proxmox identity for OpenTofu

Created 11/09/2026. Provisioning runs as `opentofu@pve`, never `root@pam`. The realm is the first line of defence: `pve` is Proxmox's internal user database, so the identity has **no Unix account, no shell and no SSH**. A credential that leaks out of a `.tfvars` file has nowhere to log in.

The custom role `OpenTofuProv` is granted at `/` and propagates. There are two independent dials on what an identity can do, **which** privileges the role carries and **where** it is granted, and only the first was tightened: with no host-level privilege in the role, the root path grants no reach the role does not already imply.

**What was deliberately left out**, against the privilege list that circulates in provider documentation:

- `Sys.Console`, which grants console access to the *node*, that is a root shell on the hypervisor through the API. A token holding it makes the whole "never `root@pam`" rule decorative. Nothing needs it: the provider's SSH-dependent features use real SSH with a key, not the API console.
- `Sys.Modify`, which permits rewriting the host's network configuration by API. Here that means the VLAN-aware bridge and the trunk to OPNsense, which took weeks to get right.
- The four write-capable `VM.GuestAgent.*` privileges (`FileRead`, `FileWrite`, `FileSystemMgmt`, `Unrestricted`), which amount to arbitrary command execution inside every guest, strictly more power than root on the guests themselves. Only `VM.GuestAgent.Audit` is granted, which is what the provider uses to read a new VM's address.

**Two privileges that older lists do not carry**, whose absence fails in ways that are hard to read: `SDN.Use`, because since PVE 8 attaching a NIC to a bridge goes through SDN and without it VM creation fails precisely at the network step; and `Sys.AccessNetwork`, because the provider downloads cloud images by URL.

**`VM.Monitor` no longer exists in PVE 9**, and the first attempt failed on it. The list the host itself returns shows what replaced it: the coarse "talk to the machine's control channel" privilege was split into the five `VM.GuestAgent.*`. The reusable lesson is cheaper than the documentation: `pvesh get /access/roles/Administrator` enumerates every privilege valid on the **running** version, because that role by definition holds all of them. If an `apply` ever returns 403, the fix is to add the privilege the error names with `pveum role modify`, not to paste a broader list back in.

The token is `opentofu@pve!provider` with `privsep 0`, so it carries the user's permissions instead of a second layer of intersection: the restriction that protects us is the role being narrow, and two layers saying the same thing only add places to get it wrong. It cannot log into the web interface, it appears under its own name in the task log, which finally separates "I did this" from "the automation did this", and it is revoked with `pveum user token remove opentofu@pve provider` without touching the host's root password.

One limit to expect when Phase 4 reaches the item about codifying what already exists: VM 102's `args` is a direct passthrough of arguments to KVM, and Proxmox reserves parameters of that kind to `root@pam`. If that holds, `args` cannot be managed by this token and stays a documented manual step, which is a better outcome than meeting it as a permission error halfway through an `apply`.

### CI: automatic IaC validation (GitHub Actions)

Before any real `apply`, a GitHub Actions workflow runs on every PR or push touching `infra/`:
- `tofu fmt -check` + `tofu validate`.
- **Not `tofu plan`, and the reason is structural** (settled 11/09/2026). This line used to end with "and a read-only `tofu plan`, without apply credentials, if it can run against a plan workspace", which left open something that cannot be done: the runners sit on the public internet, the Proxmox API sits on a private LAN behind the OPNsense with no port forward, and no credential fixes the absence of a route. A `plan` would need a self-hosted runner inside the network, which is a different decision with its own cost. What is left still catches the mechanical errors, because `fmt`, `validate` and the linters are all offline operations.
- `ansible-lint` over the playbooks and roles.
- `kubeval`/`kubeconform` or `helm lint` over the manifests in `infra/kubernetes/`.

This does not replace `code-review`/`security-review` (still mandatory before applying), but it catches mechanical errors (syntax, formatting, obvious bad practice) automatically and for free. The difference from CI over application code is the cost of a mistake: a malformed `tofu apply` does not fail a test, it destroys a VM.

**First IaC task** (given the current state): provision the TrueNAS VM through OpenTofu, then provision one VM and install k3s on it through Ansible (a single-node cluster to begin with) - codifying what was already planned manually in Phase 1, but with Kubernetes as the destination for the services.

## 5. Recommended execution order

1. Obsidian: open the homelab repo as a vault, install `obsidian-git`, confirm sync works between devices.
2. Slack: create the `#homelab-alerts` channel and an Incoming Webhook (requires workspace access).
3. IaC (scaffold): `infra/opentofu` + `infra/ansible` + `infra/kubernetes`, a dedicated API token on Proxmox, first VM (TrueNAS) provisioned from code.
4. CI: a GitHub Actions workflow validating `infra/` (`tofu fmt`/`validate`, `ansible-lint`, `helm lint`) before even the first real `apply` - so it is born with the safety net.
5. Kubernetes: provision one VM through OpenTofu + install k3s through Ansible (single-node cluster).
6. Monitoring: `kube-prometheus-stack` (Prometheus+Grafana) as a workload on k3s, wired to the Slack webhook. **Corrected 11/09/2026**: this step used to say "and Uptime Kuma as workloads on k3s... then self-hosted Healthchecks.io", and both halves had been overtaken. Healthchecks was dropped on 31/08 (see §3). And Uptime Kuma **stays in LXC 108**, where it has run since 31/08, because moving it into k3s would break the rule written three paragraphs above in this same document: whatever does the watching must be simpler, and depend on less, than what it watches. Putting the alerting inside the heaviest and newest thing in the project inverts that exactly, and `CHECKLIST.md` Phase 5 says so explicitly. Prometheus and Grafana are a different case: they are for history and graphs, not for the alert that has to arrive when everything else is on fire.
7. Application services: migrate Jellyfin and Nextcloud to manifests/Helm on k3s, with storage pointing at TrueNAS.
8. Claude Code: install the official Slack plugin and HashiCorp's Terraform skills; optionally the Obsidian MCP later on.

## 6. Security notes
- Never commit tokens, API keys or passwords in plain text - not in `.tfvars`, not in playbooks, not in Obsidian notes. **This repository is public since 11/08/2026**, which turns what was already good practice into a hard requirement.
- Slack webhooks are, in practice, a bearer token - treat the URL as a secret (do not paste it into shared notes).
- **Access and secrets reference (created 29/07/2026)**: `docs/SECRETS.md` holds the administrative access, tokens and paths for every service - it exists only locally (`.gitignore`) and has never been committed. The template with no real values, `docs/SECRETS.example.md`, is the one in the repo, documenting the structure. For genuinely important passwords (Proxmox, router, firewall), a password manager is the right long-term home - `SECRETS.md` is for quick reference, not the main vault.

## History

- 11/08/2026: translated to English. Two things were corrected in passing: a note claiming the repository is private (it went public on 11/08/2026), and a paragraph framing OpenTofu in terms of what recruiters look for, which was left over from an earlier cleanup and did not belong in a technical document.
- 11/09/2026: **full review of Phase 4 before writing any code**, which corrected two things here. In §4, the CI step no longer leaves a `tofu plan` as a possibility: GitHub runners cannot reach a private LAN, so it was an invitation to waste an afternoon. In §5, step 6 was sending Uptime Kuma into k3s and still installing Healthchecks, both overtaken by decisions taken in August and both contradicting §3 of this document. The wider lesson is about decision documents rather than about tooling: a decision written in one section does not propagate to the execution order in another, and the execution order is the part people actually follow.
- 11/09/2026: added "The Proxmox identity for OpenTofu" to section 4, recording the role actually created and, more usefully, the three privileges left out of it on purpose. The widely copied provider privilege list includes `Sys.Console`, which is a root shell on the hypervisor through the API; granting it would have left section 6's rule about never committing secrets as the only real protection.
