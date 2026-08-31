# Monitoring and Alerting

How the homelab watches itself, and why it is built the way it is. The decisions live here alongside the mechanics, because in this case the mechanics only make sense once you know what they are defending against.

This document exists because of a specific failure. Between 18 and 24 August 2026 the storage stalled repeatedly for six days without anyone noticing, and the day after, the host reached a load average of 1633 with 741MB of memory left. Neither was detected: both were found by looking. Everything below is shaped by the question *what would have caught that?*

## Two ways to watch, and why both are here

**Pull - the watcher asks.** Uptime Kuma sends an HTTP request to Jellyfin every sixty seconds. If something answers, green. It is the classic model and it serves web services well.

It has one flaw, and it cost six days: **it only detects what it knows to ask.** A TCP check against NFS on port 2049 would have answered "open" throughout the entire August incident, because what accepts a TCP connection is the kernel's socket layer, long before any service looks at it. `showmount` answered too, because `mountd` reads export configuration and never touches the data. Every conventional check reported healthy while `nfsd` was dead.

**Push - the watched proves it is alive.** Uptime Kuma asks nothing. It waits for a signal, and raises the alarm if none arrives in time.

The inversion is subtle and decisive. Under pull, **whatever answers decides** that things are fine. Under push, the check decides, and it only sends the signal **after proving** the thing works. **Silence becomes the alarm** - and silence cannot be faked, because a system that is stuck cannot claim to be fine; it cannot do anything at all.

This is a *dead man's switch*, named for the same device on a train: it requires continuous active presence, and absence is what triggers it.

Both models are in use. The nine conventional monitors are cheap and useful. The two that matter are push.

## What is installed, and where

| Component | Where it lives | Role |
|---|---|---|
| **Uptime Kuma** | LXC 108, `192.168.1.91:3001` | Receives, evaluates, alerts |
| **`monitor-push.sh`** | **Proxmox host**, `/usr/local/bin/` | Performs the real checks |
| **cron** | Proxmox host, every minute | Runs the script |
| **Slack webhook** | Configured inside Uptime Kuma | Delivers the alert |

There is **one** script. It performs two checks that feed two separate monitors.

**Why the script runs on the host rather than in the container**: the NFS mounts are mounted on the host. Inside LXC 108 there is no `/mnt/pve/media-nfs`, so the check that matters is impossible to perform there. That constraint is what forced the push model, and it turned out to be the better design anyway.

### Why the monitor lives on the flat network

Uptime Kuma sits on VLAN 1, not in the Management zone, and not as a workload on k3s. Both were considered and rejected for the same reason.

To raise an alert it has to reach the internet. From the flat network it does that through the switch and the router, **without depending on the firewall it is supposed to be watching**. From Management, an OPNsense failure would leave it unable to tell anyone - including about the OPNsense failure.

The general form of that rule is worth keeping: **whatever does the watching must be simpler, and depend on less, than what it watches.**

It also starts early. `startup order=3` puts it up right after the firewall and *before* the services, because the system fell over on 23/08 during exactly that window, and a monitor that starts last never sees the most interesting minute of the day.

## The path of an alert

```
cron (every minute, on the host)
  └─ flock: if the previous run is still going, do not start another
      └─ monitor-push.sh
          ├─ real ls on the 3 mounts, 20s hard timeout each
          │   └─ all three answered?  →  curl .../api/push/<nfs-token>
          │       any failure or timeout? → send nothing
          └─ read load, available memory, I/O pressure
              └─ all within thresholds? → curl .../api/push/<host-token>
                  any breached? → send nothing

Uptime Kuma (LXC 108)
  └─ 120s with no signal? → monitor goes red
      └─ webhook → Slack #homelab-alerts → phone
```

The push tokens and the webhook URL are secrets - anyone holding them can forge a heartbeat or post to the channel. They live in `SECRETS.md`, never in this repository.

## The script

Reproduced with the tokens redacted; the working copy is at `/usr/local/bin/monitor-push.sh` on the Proxmox host.

```bash
#!/bin/bash
# Dead man's switch for Uptime Kuma.
# It pushes ONLY when a check genuinely passes. Silence is the alarm.

KUMA="http://192.168.1.91:3001/api/push"
NFS_TOKEN="<see SECRETS.md>"
HOST_TOKEN="<see SECRETS.md>"

MAX_LOAD=20
MIN_AVAIL_MB=800
MAX_PSI_FULL=50          # /proc/pressure/io, "full" avg60, percent

push() {  # $1=token  $2=msg  $3=ping
  curl -fsS -m 10 --get \
    --data-urlencode "status=up" \
    --data-urlencode "msg=$2" \
    --data-urlencode "ping=$3" \
    "$KUMA/$1" >/dev/null 2>&1
}

# --- NFS mounts: a real directory read, with a hard timeout ---
START=$(date +%s%N)
FAIL=""
for m in media shares nextcloud; do
  timeout 20 ls "/mnt/pve/${m}-nfs" >/dev/null 2>&1 || FAIL="${FAIL} ${m}"
done
MS=$(( ($(date +%s%N) - START) / 1000000 ))
[ -z "$FAIL" ] && push "$NFS_TOKEN" "media shares nextcloud ok" "$MS"

# --- Host health: load, available memory, I/O pressure ---
LOAD1=$(cut -d' ' -f1 /proc/loadavg)
AVAIL=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
PSI=$(awk '/^full/{split($3,a,"="); printf "%.1f", a[2]}' /proc/pressure/io)

if awk -v v="$LOAD1" -v m="$MAX_LOAD"      'BEGIN{exit !(v<m)}' \
&& [ "$AVAIL" -gt "$MIN_AVAIL_MB" ] \
&& awk -v v="$PSI"   -v m="$MAX_PSI_FULL" 'BEGIN{exit !(v<m)}'; then
  push "$HOST_TOKEN" "load=${LOAD1} avail=${AVAIL}MB psi=${PSI}%" "$LOAD1"
fi
```

Scheduled as:

```
* * * * * /usr/bin/flock -n /run/monitor-push.lock /usr/local/bin/monitor-push.sh
```

## The monitors

**The two that matter**, both push, and the only ones that would have caught this month's real failures:

| Monitor | What it demands to stay green |
|---|---|
| `NFS mounts (host)` | All three `ls` answer in under 20 seconds each |
| `Host health (Proxmox)` | Load below 20, more than 800MB available, I/O pressure `full` below 50% |

**Nine conventional ones**, HTTP and ping: Proxmox, Jellyfin, Nextcloud, Caddy, TrueNAS UI, router, switch, and internet reachability. Useful and cheap, but they report *"it answered"*, not *"it works"*.

Note for the HTTPS ones on internal services: TrueNAS and Proxmox serve self-signed certificates, so **Ignore TLS/SSL errors** has to be enabled or the monitor reports down with `self-signed certificate`. The trade is that certificate expiry stops being detected - irrelevant while the certificates were never trustworthy to begin with, worth revisiting if Caddy ever issues real ones.

## Three design decisions worth keeping

**Response time is not decoration.** The NFS monitor reports the real duration of the three `ls` calls as its response time, and Uptime Kuma graphs it. That gives something never available before: **degradation becomes visible before failure**. The August incident did not break suddenly, it worsened over days. That graph would have shown the line climbing long before anything stopped.

**`flock` is a decision, not a detail.** If one run hangs, the next does not start. No heartbeat, alarm fires. That is the correct behaviour: a monitor that piles up on itself ends up masking the very problem it exists to catch.

**Thresholds come from a real incident, not from taste.** Load 20 and 800MB were chosen because on 25/08 the host reached load 1633 with 741MB available. They are starting points, not truth: if legitimate boot storms trip them, raise `MAX_LOAD` rather than widen the silence.

## I/O pressure, the earliest signal

`/proc/pressure/io` measures how long processes spent **blocked waiting on disk**, and has two lines:

- **`some`** - at least one task was stalled
- **`full`** - *everything* was stalled, meaning the machine got no work done

The check uses `full`, 60-second average, threshold 50%. During the incidents it sat at 98%.

It is the **earliest of the three signals**. Load average is a consequence: it climbs because processes accumulate waiting. I/O pressure measures the cause directly, and moves first.

## When an alert fires

**`NFS mounts` red** means at least one mount did not answer within 20 seconds. This is the August pattern, and the first command is the one that separates a saturated disk from a starved one:

```bash
iostat -x 5 3 sdb; ps -eo stat,comm --no-headers | awk '$1 ~ /^D/' | wc -l
```

`sdb` near 100% is a capacity problem. **`sdb` at 0% with processes in `D` is a block above it**, in ZFS - and reading that as "the disk is fine" is what cost eleven days in August.

**`Host health` red** tells you which of the three thresholds broke, through the message in the monitor's history: it carries `load=`, `avail=` and `psi=`. That is why they are in the message rather than only in the graph.

**Both red at once** is the full cascade. The recovery runbook is in `SECRETS.md`, under "Very high load with the disk idle".

## What is not covered yet

- **TrueNAS restarting unexpectedly** - it rebooted itself six times on 24/08 and nobody noticed until the boot list was read by chance
- **Scheduled jobs that stop running at all** - a dead man's switch for the 04:00 backup and the ZFS scrub, which Uptime Kuma cannot see because their absence produces no failure, only silence
- **History and graphs beyond Uptime Kuma's retention** - Prometheus and Grafana, deliberately deferred: it is the alerting that has value here, not the dashboards

## History

- 26/08/2026: **document created, along with the monitoring itself**. LXC 108 with Uptime Kuma, the push script on the Proxmox host, cron under `flock`, and the Slack webhook - tested by stopping a real container rather than trusting the test button. This is the first point in the project where a failure can announce itself: every incident until now was found by noticing something was broken, sometimes days late.
- 26/08/2026: **I/O pressure added to the host check** (`/proc/pressure/io`, `full` avg60, threshold 50%). It is the earliest of the three signals, because load average only rises once processes have already accumulated waiting, while I/O pressure measures the cause directly.
