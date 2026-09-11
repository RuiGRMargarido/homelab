# `infra/` - Infrastructure as Code

Everything in this tree describes the homelab as code. It is not documentation of what was done by hand: if something is in here, it is meant to be the thing that actually does it.

The reasoning behind each choice lives in [TOOLING.md sections 4 and 5](../docs/TOOLING.md#4-infrastructure-as-code). The status of each task lives in [CHECKLIST.md Phase 4](../docs/CHECKLIST.md). This file is the operational one: what each folder owns, and how to run it.

## The three layers

| Folder | Owns | Runs from |
|---|---|---|
| `opentofu/` | Creating and destroying VMs and LXCs on Proxmox. The shape of the machine: cores, memory, disks, which VLAN its NIC is tagged into | Windows (PowerShell) |
| `ansible/` | Configuring the inside of those machines: packages, users, k3s itself | **WSL2**, because Ansible does not run on Windows as a control node |
| `kubernetes/` | The application workloads on k3s, as manifests and Helm values | Windows (`kubectl`, `helm`) |

The split is not arbitrary. OpenTofu knows that a VM exists and how big it is, and knows nothing about what is installed inside it. Ansible knows what is installed and cannot create the machine. The seam between them is the machine being reachable over SSH, which is also why that seam is where things break.

## Prerequisites

Installed 11/09/2026. Versions are recorded because a version skew is the most likely cause of something behaving differently later:

| Tool | Version | Where |
|---|---|---|
| OpenTofu | 1.12.6 | Windows, `winget` |
| Helm | 4.3.0 | Windows, `winget` |
| `kubectl` | 1.34.1 in practice | Windows. Note: a 1.37.0 was installed deliberately, but the one Docker Desktop puts on the machine-level `PATH` is the one that answers. See CHECKLIST Phase 4 |
| `ansible-core` | 2.21.4 | WSL2 (Ubuntu 24.04), as `root` |
| `ansible-lint` | 26.8.0 | WSL2 |

## How it connects to Proxmox

OpenTofu talks to the Proxmox API at **`https://192.168.1.206:8006/`**, the host's flat-network address, with `insecure = true` because the certificate is self-signed.

That address is the only one that answers from the PC: the Management address `10.10.30.2:8006` is unreachable from here, which was measured rather than assumed. It is also a **leftover** from the network migration of 06/08/2026, kept "for now", so two things follow. Removing it from the host silently breaks every `apply`. And the correct long-term fix is the still-open Phase 2 item about allowing the PC's address into the Management zone, at which point this becomes one variable rather than a rewrite.

Provisioning runs as **`opentofu@pve`**, never `root@pam`. What that identity may and may not do, and which privileges were deliberately refused, is in [TOOLING.md](../docs/TOOLING.md#the-proxmox-identity-for-opentofu).

## Secrets

Nothing secret is in this tree, and the `.gitignore` is what enforces it rather than discipline:

- `terraform.tfvars` holds the API token and is ignored. `terraform.tfvars.example` is the committed template. The provider wants the token as **one single string**, `opentofu@pve!provider=<secret>`, which is the kind of detail that produces an unhelpful error when it is wrong.
- `*.tfstate` is ignored, and this is the one that matters most. State is not a cache: it holds every attribute of every managed resource in clear text, and this repository is public.
- `.terraform.lock.hcl` **is** committed, deliberately. It pins the provider hashes and is what makes `init` reproducible.
- The k3s `kubeconfig` is an administrator credential for the cluster. It lives in `~/.kube/config`, outside the repo, and is recorded in `SECRETS.md`.

## Running it, in order

From the repository root. The first three are safe to run at any time and change nothing:

```bash
tofu -chdir=infra/opentofu init
tofu -chdir=infra/opentofu fmt -check -recursive
tofu -chdir=infra/opentofu validate
```

Then the one that reads real infrastructure and still changes nothing:

```bash
tofu -chdir=infra/opentofu plan
```

And only then, deliberately and never with `-auto-approve`:

```bash
tofu -chdir=infra/opentofu apply
```

Ansible runs from WSL2, not from PowerShell:

```bash
wsl -d Ubuntu -- bash -lc "cd /mnt/c/Users/ruigr/Documents/GitHub/homelab/infra/ansible && ansible-playbook -i inventory site.yml"
```

## Rules that are not negotiable here

1. **Read the `plan` before every `apply`.** The difference between CI over application code and CI over infrastructure is the cost of a mistake: a malformed change does not fail a test, it destroys a VM.
2. **`code-review` and `security-review` before anything that touches real infrastructure.** The GitHub Actions workflow catches mechanical errors, not bad ideas.
3. **VM 102 is imported, never created.** It carries the disk passthrough and every byte of data in this homelab. After importing it, `tofu plan` must report *no changes*; while it wants to change something, the code does not yet describe reality.
4. **No `tofu plan` in CI, and it is not an oversight.** The runners are on the public internet and the Proxmox API is on a private LAN behind the firewall. No credential fixes a missing route.
