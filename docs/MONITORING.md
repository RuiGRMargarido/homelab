# Monitoring and Alerting

How the homelab watches itself, and why it is built the way it is. The decisions live here alongside the mechanics, because in this case the mechanics only make sense once you know what they are defending against.

This document exists because of a specific failure. Between 18 and 24 August 2026 the storage stalled repeatedly for six days without anyone noticing, and the day after, the host reached a load average of 1633 with 741MB of memory left. Neither was detected: both were found by looking. Everything below is shaped by the question *what would have caught that?*

## Two ways to watch, and why both are here

**Pull - the watcher asks.** Uptime Kuma sends an HTTP request to Jellyfin every sixty seconds. If something answers, green. It is the classic model and it serves web services well.

It has one flaw, and it cost six days: **it only detects what it knows to ask.** A TCP check against NFS on port 2049 would have answered "open" throughout the entire August incident, because what accepts a TCP connection is the kernel's socket layer, long before any service looks at it. `showmount` answered too, because `mountd` reads export configuration and never touches the data. Every conventional check reported healthy while `nfsd` was dead.

**Push - the watched proves it is alive.** Uptime Kuma asks nothing. It waits for a signal, and raises the alarm if none arrives in time.

The inversion is subtle and decisive. Under pull, **whatever answers decides** that things are fine. Under push, the check decides, and it only sends the signal **after proving** the thing works. **Silence becomes the alarm** - and silence cannot be faked, because a system that is stuck cannot claim to be fine; it cannot do anything at all.

This is a *dead man's switch*, named for the same device on a train: it requires continuous active presence, and absence is what triggers it.

Both models are in use. The nine conventional monitors are cheap and useful. The five that matter are push.

## What is installed, and where

| Component | Where it lives | Role |
|---|---|---|
| **Uptime Kuma** | LXC 108, `192.168.1.91:3001` | Receives, evaluates, alerts |
| **`monitor-push.sh`** | **Proxmox host**, `/usr/local/bin/` | Performs the real checks |
| **cron** | Proxmox host, every minute | Runs the script |
| **Slack webhook** | Configured inside Uptime Kuma | Delivers the alert |

There is **one** script on the host. It performs three checks feeding three monitors; the two covering scheduled jobs live elsewhere - one inside the backup script, one as a cron job inside TrueNAS.

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
      └─ monitor-push.sh          (cheapest check first, see "Why the checks run in that order")
          ├─ 1. read load, available memory, I/O pressure   [instant, /proc only]
          │      └─ all within thresholds? → curl .../api/push/<host-token>
          │         any breached? → send nothing
          ├─ 2. real ls on the 3 mounts, 20s hard timeout each
          │      └─ all three answered? → curl .../api/push/<nfs-token>
          │         any failure or timeout? → send nothing
          └─ 3. guest uptime via the QEMU agent, 45s timeout
                 └─ above 30 minutes? → curl .../api/push/<truenas-token>
                    just restarted, or agent silent? → send nothing
                    could not even ask? → send nothing, and log to
                                          /var/log/monitor-push.err

Separately, outside this script:
  backup-homelab.sh, final line   → curl .../api/push/<backup-token>
  cron inside TrueNAS, daily      → curl .../api/push/<scrub-token>  (if scrub age < 55d)

Uptime Kuma (LXC 108)
  └─ interval elapsed with no signal? → monitor goes red
      └─ webhook → Slack #homelab-alerts → phone
```

The push tokens and the webhook URL are secrets - anyone holding them can forge a heartbeat or post to the channel. They live in `SECRETS.md`, never in this repository.

## The script

Reproduced with the tokens redacted; the working copy is at `/usr/local/bin/monitor-push.sh` on the Proxmox host.

```bash
#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# Dead man's switch for Uptime Kuma.
# It pushes ONLY when a check genuinely passes. Silence is the alarm.
#
# The PATH above is not decoration. cron runs with PATH=/usr/bin:/bin and qm
# lives in /usr/sbin, so without it the TrueNAS check silently does nothing.
#
# Order matters: the cheap checks run first, so an expensive one that hangs
# cannot delay them. flock then prevents overlapping runs.

KUMA="http://192.168.1.91:3001/api/push"
HOST_TOKEN="<see SECRETS.md>"
NFS_TOKEN="<see SECRETS.md>"
TRUENAS_TOKEN="<see SECRETS.md>"

MAX_LOAD=20
MIN_AVAIL_MB=800
MAX_PSI_FULL=50          # /proc/pressure/io, "full" avg60, percent
MIN_UPTIME_S=1800        # below this, TrueNAS restarted recently

push() {  # $1=token  $2=msg  $3=ping
  curl -fsS -m 10 --get \
    --data-urlencode "status=up" \
    --data-urlencode "msg=$2" \
    --data-urlencode "ping=$3" \
    "$KUMA/$1" >/dev/null 2>&1
}

# --- 1. Host health: instant, reads /proc only ---
LOAD1=$(cut -d' ' -f1 /proc/loadavg)
AVAIL=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
PSI=$(awk '/^full/{split($3,a,"="); printf "%.1f", a[2]}' /proc/pressure/io)

if awk -v v="$LOAD1" -v m="$MAX_LOAD"      'BEGIN{exit !(v<m)}' \
&& [ "$AVAIL" -gt "$MIN_AVAIL_MB" ] \
&& awk -v v="$PSI"   -v m="$MAX_PSI_FULL" 'BEGIN{exit !(v<m)}'; then
  push "$HOST_TOKEN" "load=${LOAD1} avail=${AVAIL}MB psi=${PSI}%" "$LOAD1"
fi

# --- 2. NFS mounts: a real directory read, with a hard timeout ---
START=$(date +%s%N)
FAIL=""
for m in media shares nextcloud; do
  timeout 20 ls "/mnt/pve/${m}-nfs" >/dev/null 2>&1 || FAIL="${FAIL} ${m}"
done
MS=$(( ($(date +%s%N) - START) / 1000000 ))
[ -z "$FAIL" ] && push "$NFS_TOKEN" "media shares nextcloud ok" "$MS"

# --- 3. TrueNAS guest uptime ---
# Reads the GUEST's uptime, not the QEMU process start time: on 24/08/2026 the
# guest rebooted six times while the QEMU process kept running, so watching the
# process would have seen nothing.
# Absolute path to qm, and an error log rather than /dev/null: both were paid
# for on 01/09, see History.
UP=$(timeout 45 /usr/sbin/qm guest exec 102 -- /bin/cat /proc/uptime 2>>/var/log/monitor-push.err \
     | sed -n 's/.*"out-data" : "\([0-9][0-9]*\)\..*/\1/p')
if [ -n "$UP" ] && [ "$UP" -gt "$MIN_UPTIME_S" ]; then
  push "$TRUENAS_TOKEN" "uptime $((UP/86400))d $(( (UP%86400)/3600 ))h" ""
fi
```

Scheduled as:

```
* * * * * /usr/bin/flock -n /run/monitor-push.lock /usr/local/bin/monitor-push.sh
```

## The monitors

**The five that matter** are all push. The first two are the only ones that would have caught this month's real failures; two cover the scheduled jobs, whose failure mode is invisible to any availability check; and the last catches a restart the hypervisor itself would not have seen:

| Monitor | What it demands to stay green |
|---|---|
| `NFS mounts (host)` | All three `ls` answer in under 20 seconds each |
| `Host health (Proxmox)` | Load below 20, more than 800MB available, I/O pressure `full` below 50% |
| `Backup diário (04:00)` | The backup script reached its final line, which `set -e` guarantees only happens if both `rsync` runs succeeded |
| `ZFS scrub` | A daily check inside TrueNAS finds the last scrub to be less than 55 days old |
| `TrueNAS uptime` | The guest reports an uptime above 30 minutes, meaning it has not just restarted |

### Detecting a restart nobody asked for

On 24/08/2026 TrueNAS rebooted **six times** and it was found only by reading `journalctl --list-boots` on a hunch. Everything recovered each time, so nothing looked broken afterwards.

**The obvious design would have missed it entirely.** Watching the QEMU process on the host - has it restarted? - seems like the natural check, and it would have reported nothing at all: the process had been running since 18/08 while the guest's own boot list showed restarts from the 21st onward. A watchdog performing a hardware reset does exactly that, restarting the guest operating system without the hypervisor process ever dying.

So the check reads **the guest's own uptime**, through the QEMU guest agent, which is the only place that fact exists.

The logic is inverted like the others: it pushes **only when uptime is above 30 minutes**. A restart therefore produces silence, an alert around two minutes later, and self-recovery half an hour after that. Planned reboots trip it too, which is correct - a reboot is worth being told about, and one you performed yourself is trivially dismissed. The alternative, alerting only on *unexpected* restarts, would require the monitor to know your intentions.

A silent guest agent produces exactly the same silence as a restart, and the monitor cannot tell the two apart. For an agent that genuinely fails to answer that is acceptable, because a TrueNAS in that state is news either way.

It is **not** acceptable for the third case, which this document originally failed to consider and which then cost an hour on 01/09: the script never managing to *ask* the question at all. A dead man's switch is structurally incapable of reporting its own defects, so the defect has to leave a trace somewhere else. That is why stderr from the guest agent call is appended to `/var/log/monitor-push.err` instead of being discarded. **When this monitor fires, that file is the first thing to read**, before touching TrueNAS at all.

### Why the checks run in that order

The host health block runs **first**, and that is deliberate rather than incidental. It reads only files under `/proc`, so it is instantaneous and can never block. The NFS check can consume up to sixty seconds, and the guest agent call up to forty-five more.

In the original version the NFS check came first. Combined with `flock`, that meant a hanging mount could push the whole run past a minute, so subsequent runs were skipped - and **the cheapest, most reliable check stopped reporting precisely during the incident it was most useful for**. Ordering by cost fixes that: whatever is guaranteed to complete goes first.

### Scheduled jobs

These two catch what an availability check structurally cannot see. A job that **fails** produces an error; a job that **stops running** produces nothing at all, and silence is the only evidence there is.

**The backup** was the easy one. The script already begins with `set -e`, so it aborts on the first error and never reaches the end. That makes a single `curl` on the last line an exact success condition, with no status checking needed - the control flow already encodes it.

**The scrub needed the question inverted.** The obvious design is for the job to announce itself when it runs. That fails here for two reasons: Uptime Kuma caps the heartbeat interval at 24 days while the scrub cadence is longer, and more importantly, a job that is **removed from the schedule** would never announce anything, and nothing would notice.

So instead a daily cron inside TrueNAS reads `zpool status`, works out how many days ago the last scrub finished, and only sends a heartbeat if that number is under the threshold. The interval matches **how often we check**, not how often the job runs - and it detects the schedule quietly disappearing, which the obvious design does not.

**Getting that threshold right took arithmetic, and the first attempt was wrong.** TrueNAS scrub tasks have two parameters: a schedule saying *when it may run* (here: Sundays at 00:00) and `Threshold Days` saying *how long must have passed* to bother (here: 35). The real worst-case interval is therefore 35 days plus up to 6 more waiting for the next Sunday: **41 days**. The alarm was first set at 40, which would have fired on its own with nothing wrong.

That mistake is worth recording, because a false alarm is worse than no alarm: **it teaches you to ignore the alert**, and the next one to fire will be real. The threshold is now 55 days - the worst case plus a fortnight to notice and act.

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

**`TrueNAS uptime` red** has two causes that look identical from Uptime Kuma and call for opposite responses. One command separates them:

```bash
tail /var/log/monitor-push.err; qm guest exec 102 -- /bin/cat /proc/uptime
```

Anything in the error log means **the check is broken, not TrueNAS**. An empty log plus a command that answers normally means the restart was real, and the next place to look is `journalctl --list-boots` inside the guest.

**Both red at once** is the full cascade. The recovery runbook is in `SECRETS.md`, under "Very high load with the disk idle".

## What is not covered yet

- **History and graphs beyond Uptime Kuma's retention** - Prometheus and Grafana, deliberately deferred: it is the alerting that has value here, not the dashboards

## History

- 31/08/2026: **document created, along with the monitoring itself**. LXC 108 with Uptime Kuma, the push script on the Proxmox host, cron under `flock`, and the Slack webhook - tested by stopping a real container rather than trusting the test button. This is the first point in the project where a failure can announce itself: every incident until now was found by noticing something was broken, sometimes days late.
- 31/08/2026: **I/O pressure added to the host check** (`/proc/pressure/io`, `full` avg60, threshold 50%). It is the earliest of the three signals, because load average only rises once processes have already accumulated waiting, while I/O pressure measures the cause directly.
- 31/08/2026: **scheduled jobs covered with Push monitors rather than a second tool**. Healthchecks.io had been in the plan since July for exactly this, and was dropped on realising Uptime Kuma's Push monitors already implement the same pattern - see `TOOLING.md` §3 for the full reasoning. The short version: a Django and Postgres stack to watch two cron jobs would have inverted the rule stated further up this document, that the watcher must be simpler and depend on less than what it watches.
- 31/08/2026: **scheduled jobs covered**, and a dating error in this document corrected along the way - the monitoring work was done on 31/08, not 26/08 as first recorded. The backup pushes from the last line of its script, which `set -e` makes an exact success condition. The scrub is checked differently: a daily cron inside TrueNAS reads the age of the last scrub and only sends a heartbeat while it is recent, so the monitor also catches the schedule being removed, which a job-announces-itself design never would. The threshold was set to 40 days first and that was wrong: with `Threshold Days` at 35 and the task allowed to run only on Sundays, the real worst case is 41 days, so it would have fired on its own. Corrected to 55. **A false alarm is worse than no alarm** - it teaches you to ignore the alert, and the next one will be real.
- 01/09/2026: **restart detection added, and the check order corrected** (this monitor did not actually work until the fix recorded below, and the two entries should be read together). `TrueNAS uptime` reads the guest's own uptime through the QEMU guest agent and pushes only while it exceeds thirty minutes, so a restart shows up as silence and reaches Slack about two minutes later. The design point worth keeping: watching the **QEMU process** would have detected none of the six restarts of 24/08, because the process ran continuously from the 18th while the guest rebooted itself from the 21st - a hardware reset restarts the operating system without the hypervisor process ever dying. The same commit reordered the script so the host-health block runs first: it reads only `/proc` and cannot block, whereas the NFS check can take a minute. With `flock` preventing overlap, having the slow check first meant the cheapest and most reliable one stopped reporting exactly during the incidents it existed for.
- 01/09/2026: **the restart monitor was itself broken, and how it broke is the more useful lesson**. `TrueNAS uptime` had never once fired from cron. Every green beat it ever showed came from a manual test run, which is why it looked healthy for a whole day and why its uptime figure sat at 4.57%. The cause was mundane: `qm` lives in `/usr/sbin`, cron runs with `PATH=/usr/bin:/bin`, and the `2>/dev/null` on that line threw away the `command not found` that would have answered the question in one glance. Three hypotheses were tried and killed by measurement before that one: the guest agent starved by the concurrent backup (it answered in 1.2 seconds), the `sed` parser (it returned the right number), and `flock` contention (no run was ever stuck, and the whole script completed in 1.2 seconds). What separated the cases was running the script under cron's own environment rather than a login shell, `env -i PATH=/usr/bin:/bin /usr/local/bin/monitor-push.sh`, which failed instantly. Fixed with an explicit `PATH` at the top of the script and an absolute path on `qm`, and stderr from that call now appends to `/var/log/monitor-push.err` so the next broken check leaves evidence instead of silence. The uncomfortable part: the identical mistake had been made and corrected in the TrueNAS scrub cron job hours earlier, where `/usr/sbin/zpool` and `/usr/bin/curl` were spelled out from the start. **A lesson applied in one place and not carried to the neighbouring one is not yet a lesson.**
- 01/09/2026: **and the first thing the working monitor reported was a restart nobody had seen**. With the check finally running, the guest's `/proc/uptime` read 25h50m while the QEMU process had been up for seven days: **TrueNAS restarted itself on 30/08 at roughly 21:50 UTC**, and at the time nothing noticed. Third spontaneous restart on record, after the six of 24/08, and precisely the scenario the monitor exists for. The root cause of these restarts is still open, tracked in `CHECKLIST.md`.
