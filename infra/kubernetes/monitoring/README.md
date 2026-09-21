# `monitoring/` - Prometheus and Grafana

`kube-prometheus-stack` 91.4.1, the community chart that bundles the Prometheus operator, Prometheus, Grafana with its dashboards, kube-state-metrics and node-exporter. It is installed with Helm, since it is third-party software: the chart is maintained upstream, and this folder keeps only what differs from it.

It is here for history: "why is it slow", "this has been degrading for weeks". **Alerting stays with Uptime Kuma** in LXC 108, which reaches Slack without depending on anything it watches, while this stack lives inside the heaviest thing in the project. Prometheus still evaluates the chart's rules and shows them in its own UI; nothing sends them anywhere.

| File | What |
|---|---|
| `values.yaml` | Every difference from the chart's defaults, each with its reason |
| `namespaces.yaml` | The two namespaces, applied before the chart |
| `scrapeconfig-proxmox-host.yaml` | The Proxmox host as a target, our own object beside the chart |

## What the chart produces, read before installing

Rendered with `helm template` on 18/09/2026, with these values, for Kubernetes 1.36.4, and read object by object before anything touched the cluster:

| Pods | Namespace | Pod Security |
|---|---|---|
| Prometheus operator, Prometheus, Grafana, kube-state-metrics, the two jobs that issue the operator's webhook certificate | `monitoring` | `restricted` |
| node-exporter | `monitoring-node` | `privileged`: host network, host PID, and the node's `/proc`, `/sys` and `/` |

- **99 objects, and nothing existing is modified.** 82 in `monitoring`, 4 in `monitoring-node`, one Service in `kube-system` that exposes CoreDNS's metrics, and 12 cluster-wide ones: the permissions, and the two admission webhooks that validate the operator's own resources.
- **The Prometheus pod is not in the output**, because the operator creates it at runtime. Its settings were read in the operator's source at v0.94.0 instead: no privilege escalation, every capability dropped and a read-only root filesystem for each container, and a pod running as a non-root user with the runtime's default seccomp profile. So it passes `restricted` too.
- **Sized to the node.** Memory requests add up to about 900Mi, on a node measured with about 2.7GB available. They were 780Mi at the install; two limits were raised the same day, after measuring the running stack, see below. Memory is limited, CPU only requested.
- **What it scrapes**: the Kubernetes API, the kubelet and its container metrics, CoreDNS, kube-state-metrics, node-exporter on the node, and the stack itself. The controller manager, the scheduler, the proxy and etcd are left out: k3s runs the first three inside its own process and keeps a single node's state in SQLite, so their monitors would report them down forever.
- **Data** on a 10Gi volume from the local-path provisioner, kept for 15 days or 8GB. The provisioner does not enforce the volume's size, so the retention size is the real limit on the node's 32GB disk.
- **Grafana** at `http://10.10.20.11/grafana/`, through Traefik and the WireGuard tunnel, like `/whoami`. It has no volume: its dashboards come from the chart, and anything changed in its UI is lost on a restart.

## Installing it

From WSL2, at the repository root, with the tunnel up and `KUBECONFIG=~/.kube/homelab-k3s.yaml`.

1. **Fetch the chart and check it** against the digest GitHub publishes for the release file. It is the digest the chart was reviewed with, and the CI checks the same one.

   ```bash
   curl -fsSLo /tmp/kps.tgz https://github.com/prometheus-community/helm-charts/releases/download/kube-prometheus-stack-91.4.1/kube-prometheus-stack-91.4.1.tgz && echo "1bd5e7a88e758ed3ec22db0fe6e72b1352f3f0e7e5a93c79979f7edf361becdb  /tmp/kps.tgz" | sha256sum -c -
   ```

2. **The namespaces**, before anything that lives in them:

   ```bash
   kubectl apply -f infra/kubernetes/monitoring/namespaces.yaml
   ```

3. **Grafana's admin credentials**, created by hand and never in this repository. The password then goes into `SECRETS.md`:

   ```bash
   kubectl -n monitoring create secret generic grafana-admin --from-literal=admin-user=admin --from-literal=admin-password="$(openssl rand -base64 24)"
   ```

   ```bash
   kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d; echo
   ```

4. **The install.** Helm 4 applies it on the server side, as the field manager `helm`.

   ```bash
   helm upgrade --install kps /tmp/kps.tgz -n monitoring -f infra/kubernetes/monitoring/values.yaml --wait --timeout 10m
   ```

The first install has no plan beyond the reading above. Everything it creates is new, and the chart's own resource types do not exist until it installs them, so neither `kubectl diff` nor Helm's server-side dry run can simulate it. **From the second change on, the plan is a comparison** of what is installed with what would be, before the `upgrade`. Hooks are left out on both sides, since Helm stores them apart from the manifest, and blank lines are ignored with `-B`:

```bash
diff -B <(helm get manifest kps -n monitoring) <(helm template kps /tmp/kps.tgz -n monitoring -f infra/kubernetes/monitoring/values.yaml --no-hooks --kube-version 1.36.4)
```

Right after the first install this comparison must print nothing, which is how the plan itself gets checked before it is ever needed. Run without `-B` on 18/09/2026, it printed only two blank lines that `helm get manifest` adds at the end: the offline render matched the installed manifest line for line, all 5692 of them.

## Installed, 18/09/2026

- **Every pod running and the volume bound**: Grafana with its two sidecars, the operator, kube-state-metrics and Prometheus in `monitoring`, node-exporter in `monitoring-node`, and the 10Gi volume bound by the local-path provisioner.
- **Eleven targets, all up**: the kubelet three times (its own metrics, the containers' and the probes'), Prometheus and its config reloader, node-exporter, Grafana, the Kubernetes API, CoreDNS, the operator and kube-state-metrics.
- **Memory a few minutes after the install**: Grafana 456Mi across its three containers, Prometheus 390Mi, kube-state-metrics 29Mi, the operator 29Mi and node-exporter 12Mi, about 920Mi in all. The node went from 1353Mi, 34% of its memory, to 2658Mi, 67%.
- **Per container, ten minutes in**: Grafana 311Mi against its limit of 384Mi, and each of its sidecars about 73Mi; Prometheus 380Mi against 1Gi; the config reloader beside it 39Mi against 48Mi; the operator 30Mi and kube-state-metrics 23Mi. Two of those were too close to their limit for a process whose peaks had not been seen yet, so Grafana went to 512Mi, with its request raised to 256Mi to match what it actually uses, and the config reloader to 64Mi. The chart sets Grafana's Go memory limit to 90% of the container's, so it followed on its own, from 345MiB to 460MiB. It was the first change after the install, and so the first real use of the plan: the comparison showed exactly the six differences previewed locally before the commit, and nothing else. The upgrade, revision 2, restarted Grafana and the operator, and the operator then restarted Prometheus once to give its reloader the new limit, as expected; the comparison printed nothing afterwards.
- **The chart's own notes do not apply here.** They point at a `kps-grafana` Secret for the admin password, which is not created when the credentials come from an existing Secret: the only Secret the chart renders is Prometheus's service account token.

## The Proxmox host

Everything above watches the cluster and the VM it runs in. The hypervisor underneath is a different machine, and the one whose memory decides what else can ever run here, so it is scraped too, from 21/09/2026.

- **On the host**, Debian's `prometheus-node-exporter` package, bound to the Management address alone, `10.10.30.2:9100`, so it is not also answering on the flat network. It is installed by hand: the host is not in Ansible's inventory, which holds guests, and putting it there is a decision of its own about credentials.
- **No firewall rule was needed.** Rule 5 in [NETWORK.md](../../../docs/NETWORK.md#rules-between-zones) already lets the Trusted zone open connections anywhere, which is how TrueNAS reaches its updates; the k3s node uses the same path to reach Management.
- **The target is a `ScrapeConfig`**, since the host is not discoverable inside Kubernetes, and it carries the same job name as the cluster's node-exporter, so the chart's dashboards list the host beside the k3s node instead of needing their own.
- **What it does not cover**: per guest figures, which come from the Proxmox API rather than the host's kernel. A `prometheus-pve-exporter` would add them, and is a step of its own.

Applied with the plan first, as everything else here:

```bash
kubectl diff -f infra/kubernetes/monitoring/scrapeconfig-proxmox-host.yaml
```

```bash
kubectl apply -f infra/kubernetes/monitoring/scrapeconfig-proxmox-host.yaml
```

`kubectl diff` exits `1` when it finds differences, which is what a new object is, so the first run is expected to end in `1` and print the object it would create.
