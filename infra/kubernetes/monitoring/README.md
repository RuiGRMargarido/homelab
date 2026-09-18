# `monitoring/` - Prometheus and Grafana

`kube-prometheus-stack` 91.4.1, the community chart that bundles the Prometheus operator, Prometheus, Grafana with its dashboards, kube-state-metrics and node-exporter. It is installed with Helm, since it is third-party software: the chart is maintained upstream, and this folder keeps only what differs from it.

It is here for history: "why is it slow", "this has been degrading for weeks". **Alerting stays with Uptime Kuma** in LXC 108, which reaches Slack without depending on anything it watches, while this stack lives inside the heaviest thing in the project. Prometheus still evaluates the chart's rules and shows them in its own UI; nothing sends them anywhere.

| File | What |
|---|---|
| `values.yaml` | Every difference from the chart's defaults, each with its reason |
| `namespaces.yaml` | The two namespaces, applied before the chart |

## What the chart produces, read before installing

Rendered with `helm template` on 18/09/2026, with these values, for Kubernetes 1.36.4, and read object by object before anything touched the cluster:

| Pods | Namespace | Pod Security |
|---|---|---|
| Prometheus operator, Prometheus, Grafana, kube-state-metrics, the two jobs that issue the operator's webhook certificate | `monitoring` | `restricted` |
| node-exporter | `monitoring-node` | `privileged`: host network, host PID, and the node's `/proc`, `/sys` and `/` |

- **99 objects, and nothing existing is modified.** 82 in `monitoring`, 4 in `monitoring-node`, one Service in `kube-system` that exposes CoreDNS's metrics, and 12 cluster-wide ones: the permissions, and the two admission webhooks that validate the operator's own resources.
- **The Prometheus pod is not in the output**, because the operator creates it at runtime. Its settings were read in the operator's source at v0.94.0 instead: no privilege escalation, every capability dropped and a read-only root filesystem for each container, and a pod running as a non-root user with the runtime's default seccomp profile. So it passes `restricted` too.
- **Sized to the node.** Memory requests add up to about 780Mi, on a node measured with about 2.7GB available. Memory is limited, CPU only requested.
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

The first install has no plan beyond the reading above. Everything it creates is new, and the chart's own resource types do not exist until it installs them, so neither `kubectl diff` nor Helm's server-side dry run can simulate it. **From the second change on, the plan is a comparison** of what is installed with what would be, before the `upgrade`. Hooks are left out on both sides, since Helm stores them apart from the manifest:

```bash
diff <(helm get manifest kps -n monitoring) <(helm template kps /tmp/kps.tgz -n monitoring -f infra/kubernetes/monitoring/values.yaml --no-hooks --kube-version 1.36.4)
```

Right after the first install this comparison must print nothing. That is how the plan itself gets checked, before it is ever needed.
