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
                    could not even ask? → send nothing, and stderr goes
                                          to the journal, tag monitor-push
          └─ 4. VPN tunnel via LXC 107, 15s timeout
                 └─ gluetun healthy AND qbittorrent up AND a public IP recorded?
                    → curl .../api/push/<vpn-token>

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
SWAP=$(awk '/^SwapTotal/{t=$2}/^SwapFree/{f=$2}END{printf "%d", (t-f)/1024}' /proc/meminfo)

if awk -v v="$LOAD1" -v m="$MAX_LOAD"      'BEGIN{exit !(v<m)}' \
&& [ "$AVAIL" -gt "$MIN_AVAIL_MB" ] \
&& awk -v v="$PSI"   -v m="$MAX_PSI_FULL" 'BEGIN{exit !(v<m)}'; then
  push "$HOST_TOKEN" "load=${LOAD1} avail=${AVAIL}MB psi=${PSI}% swap=${SWAP}MB" "$LOAD1"
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
# Absolute path to qm rather than bare qm: paid for on 01/09, see History.
UP=$(timeout 45 /usr/sbin/qm guest exec 102 -- /bin/cat /proc/uptime \
     | sed -n 's/.*"out-data" : "\([0-9][0-9]*\)\..*/\1/p')
if [ -n "$UP" ] && [ "$UP" -gt "$MIN_UPTIME_S" ]; then
  push "$TRUENAS_TOKEN" "uptime $((UP/86400))d $(( (UP%86400)/3600 ))h" ""
fi

# --- 4. VPN tunnel (LXC 107) ---
# One pct exec rather than three. Each command guarantees a line even when it
# fails, with "|| echo none", otherwise the fields shift and the first value
# read becomes the next container's, which would be a false green.
VPN=$(timeout 15 pct exec 107 -- sh -c 'docker inspect --format "{{.State.Health.Status}}" gluetun 2>/dev/null || echo none; docker inspect --format "{{.State.Running}}" qbittorrent 2>/dev/null || echo none; docker exec gluetun cat /tmp/gluetun/ip 2>/dev/null || echo none' | tr -d '
' | tr '
' ' ')
GL=$(echo "$VPN" | awk '{print $1}')
QB=$(echo "$VPN" | awk '{print $2}')
VIP=$(echo "$VPN" | awk '{print $3}')
if [ "$GL" = "healthy" ] && [ "$QB" = "true" ] && [ -n "$VIP" ] && [ "$VIP" != "none" ]; then
  push "$VPN_TOKEN" "tunel ok, saida ${VIP}" ""
fi
```

Scheduled as:

```
* * * * * /usr/bin/flock -n /run/monitor-push.lock /usr/local/bin/monitor-push.sh 2>&1 | /usr/bin/logger -t monitor-push
```

**Errors go to the journal, not to a file** (changed 03/09/2026). The first version appended stderr to `/var/log/monitor-push.err`, which was better than the `/dev/null` it replaced but had a defect found on its first real use: **a trace with no timestamp cannot distinguish "this happened during last night's reboot" from "this is happening now"**. Eight lines of `ipcc_send_rec failed: Connection refused` turned out to be `qm` and `pct` talking to a `pmxcfs` that had already stopped during a shutdown, which is harmless, but proving that took a look at the file's mtime rather than at the lines themselves. Piping through `logger` gets timestamps, rotation and a consistent home for free, and on Proxmox 9 the journal is where everything else lives anyway, since there is no `/var/log/syslog`. Read it with `journalctl -t monitor-push --since today`.

**Swap is in the message rather than only in a threshold** (added 03/09/2026), because it is currently evidence in an open investigation rather than an alarm condition. See "The trap" below.

## The trap (03/09/2026, temporary)

Not monitoring in the ordinary sense: a deliberately narrow instrument built to catch one specific fault in the act.

TrueNAS restarted itself on 29/08 at 21:41:46 and on 30/08 at 21:44:52 UTC, three minutes apart on consecutive days, and in a week containing exactly two such events that is hard to read as coincidence. The per-minute heartbeat is too coarse for it: the stall that killed the guest lasted around twenty seconds and would barely move a one-minute load average.

`/usr/local/bin/trap-2143.sh` samples the host **every five seconds** across a 35-minute window, started by cron at 21:25 UTC, and appends one line per sample to `/var/log/trap-2143.log`:

```
09-03 00:20:12 load=0.20 avail=7296M swap=0M psi_io=0.00 psi_mem=0.00 psi_cpu=0.01                pswpin=4 pswpout=4 vm102_rss=2762M vm102_swap=0M
```

The fields are chosen to test one hypothesis: that pages of the QEMU process are being paged out, and a timer interrupt could not be delivered because the host was faulting them back from a busy disk. A jump in `pswpin`, or `vm102_swap` climbing in the minutes before, would move that from hypothesis to finding.

**It was tested before being trusted**, by running it under `timeout` and checking that every field was populated. That habit comes from the `PATH` bug of 01/09, where a check that had never once run looked healthy for a day. An empty field on the night the machine dies is evidence lost.

**Reading it the morning after** is a two-step job, because the host's log cannot tell you on its own whether the fault occurred: the guest reboots inside a QEMU process that survives, so nothing in the host's view changes. First ask the guest whether it restarted (`journalctl --list-boots`), then look up that time in the trap log.

**First run, 03/09/2026: the fault did not recur, and the instrument answered a different question instead.** The guest's boot list showed a single transition since 30/08, and its timestamps in PDT match to the minute the host shutdown of 02/09 at 23:25 UTC and the boot at 00:10 UTC, which is the forty-five minutes the case was open to inspect the memory modules. No spontaneous restart. That is the likeliest outcome five days after an event that happened twice, and it is not a reason to stand the trap down.

What it did catch belongs to the other open question. Across its 35-minute window, while the gluetun outage was being fixed in the same session:

```
                21:25:01     21:59:57
swap                66M         857M
pswpout          17 840      237 607     +219 767 pages, about 858MB written
pswpin            7 248       64 153      +56 905 pages, about 222MB read back
psi_io            0.00         7.93
vm102_rss        7938M        7938M       the ARC had already refilled
```

In the following 35 minutes, with the work finished, `pswpout` advanced by **171 pages**. A factor of roughly thirteen hundred. **The swapping was driven by the machine's own maintenance, not by a continuous leak**, which is a more precise and more useful answer than either of the two the experiment set out to choose between.

Both original hypotheses turned out to be partly right. There was a bad kernel trade-off, since `swappiness` at Debian's default of 60 spends guest RAM to buy page cache and a guest can neither see nor compensate for that; lowering it to 10 stopped the machine swapping at rest. And there is genuinely not enough memory, because 2.5GB of headroom disappears the moment any real work starts. `swappiness` cannot create memory that is not there.

One residue worth noting: around 800MB of process memory is still on disk and comes back only as pages are touched, roughly 50MB per half hour. Until then those processes are running degraded, every access being a read from the disk that is this platform's weakest component.

Remove it once the vCPU stall is understood. An instrument built for one question should not outlive the question, and this one has not answered its own yet.

## The monitors

**The five that matter** are all push. The first two are the only ones that would have caught this month's real failures; two cover the scheduled jobs, whose failure mode is invisible to any availability check; and the last catches a restart the hypervisor itself would not have seen:

| Monitor | What it demands to stay green |
|---|---|
| `NFS mounts (host)` | All three `ls` answer in under 20 seconds each |
| `Host health (Proxmox)` | Load below 20, more than 800MB available, I/O pressure `full` below 50% |
| `Backup diário (04:00)` | The backup script reached its final line, which `set -e` guarantees only happens if both `rsync` runs succeeded |
| `ZFS scrub` | A daily check inside TrueNAS finds the last scrub to be less than 55 days old |
| `TrueNAS uptime` | The guest reports an uptime above 30 minutes, meaning it has not just restarted |
| `VPN tunnel (gluetun)` | gluetun reports healthy, qBittorrent is running, and gluetun has recorded a public IP |

### Detecting a restart nobody asked for

On 24/08/2026 TrueNAS rebooted **six times** and it was found only by reading `journalctl --list-boots` on a hunch. Everything recovered each time, so nothing looked broken afterwards.

**The obvious design would have missed it entirely.** Watching the QEMU process on the host - has it restarted? - seems like the natural check, and it would have reported nothing at all: the process had been running since 18/08 while the guest's own boot list showed restarts from the 21st onward. A watchdog performing a hardware reset does exactly that, restarting the guest operating system without the hypervisor process ever dying.

So the check reads **the guest's own uptime**, through the QEMU guest agent, which is the only place that fact exists.

The logic is inverted like the others: it pushes **only when uptime is above 30 minutes**. A restart therefore produces silence, an alert around two minutes later, and self-recovery half an hour after that. Planned reboots trip it too, which is correct - a reboot is worth being told about, and one you performed yourself is trivially dismissed. The alternative, alerting only on *unexpected* restarts, would require the monitor to know your intentions.

A silent guest agent produces exactly the same silence as a restart, and the monitor cannot tell the two apart. For an agent that genuinely fails to answer that is acceptable, because a TrueNAS in that state is news either way.

It is **not** acceptable for the third case, which this document originally failed to consider and which then cost an hour on 01/09: the script never managing to *ask* the question at all. A dead man's switch is structurally incapable of reporting its own defects, so the defect has to leave a trace somewhere else. That is why stderr from the guest agent call is appended to `/var/log/monitor-push.err` instead of being discarded. **When this monitor fires, that file is the first thing to read**, before touching TrueNAS at all.

### Watching the tunnel, and the two checks that would have lied

Added 03/09/2026, after the media stack sat dead for ten days without anything noticing, because nothing was pointed at it.

**The obvious check is the wrong one.** qBittorrent's web interface is published on port 8080 and answers to a plain HTTP monitor. It also **keeps answering with the tunnel down**, because the published port forward works regardless and the kill switch blocks outbound traffic, not inbound. A monitor on 8080 would sit green through exactly the failure it was built to catch, which is the same shape as `showmount` answering while `nfsd` was dead in August.

**The second obvious check is worse than useless.** gluetun has an HTTP control server on port 8000 that reports tunnel state directly. Publishing it would put an API that can stop the VPN onto the flat network, which is a poor trade for a status page.

So the check reads three things from inside, through one `pct exec`, and pushes only if all three hold: gluetun **healthy**, qBittorrent **running**, and a **public IP recorded** in the file gluetun maintains at `/tmp/gluetun/ip`. Reading that file costs no external request. gluetun's own health check is already a tunnel test, since it reaches `cloudflare.com:443` and `github.com:443` *through* the tunnel and the kill switch means that can only pass while the tunnel is up.

The exit IP travels in the message, so Uptime Kuma keeps a history of which address the downloads were leaving from at any given time.

**One detail in that block is the whole reason it can be trusted.** Each of the three commands ends in `|| echo none`. Without it, a failing `docker inspect` prints nothing to stdout, three fields become two, and `awk '{print $1}'` starts reading qBittorrent's state as if it were gluetun's health. The monitor would go green at the exact moment the container vanished. It is the same class of silent defect as the cron `PATH` bug of 01/09: not a check that reports a wrong answer, but a check that quietly stops asking the right question.

### The boundary of the tunnel, as a decision

Recorded here because it was previously true but written down nowhere, which means it could not be told apart from an accident.

**Only `qbittorrent` runs inside gluetun's network namespace.** `sonarr`, `radarr`, `prowlarr` and `jellyseerr` sit on the ordinary `arr_default` bridge and reach the download client through gluetun's published port at `http://gluetun:8080`.

That covers the exposure that actually matters: **BitTorrent announces your address to every peer in the swarm**, so the torrent client is the one component whose traffic is broadcast to strangers by design. Sonarr and Radarr talk to Prowlarr, to the download client, and to metadata services, none of which is sensitive in the same way.

The deliberate residue is that **Prowlarr's indexer queries leave on the home address**. There are arguments both ways, which is why it is a decision rather than an oversight: private trackers frequently react badly to VPN ranges, and address consistency counts toward account standing; against that, the queries reveal what is being searched for, tied to the home address. It stands as it is until there is a reason to change it.

`qbittorrent` also carries `depends_on: gluetun: condition: service_healthy` (added 03/09/2026). The short `depends_on: - gluetun` form waits only for the container to **start**, leaving a window in which the client comes up against a tunnel that does not exist. Note what this does and does not buy: it is a **startup ordering guarantee only**, and does nothing if gluetun sickens later while everything is already running. What protects then is the kill switch, which held for twenty-one hours during the outage of 03/09 without a single packet escaping.

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
journalctl -t monitor-push --since today; qm guest exec 102 -- /bin/cat /proc/uptime
```

Anything in the error log means **the check is broken, not TrueNAS**. An empty log plus a command that answers normally means the restart was real, and the next place to look is `journalctl --list-boots` inside the guest.

**`VPN tunnel (gluetun)` red** means one of three things failed, and one command tells you which:

```bash
pct exec 107 -- sh -c 'docker inspect --format "gluetun: {{.State.Health.Status}}" gluetun; docker inspect --format "qbittorrent: {{.State.Running}}" qbittorrent; docker logs --tail 20 gluetun'
```

`unhealthy` with `AUTH_FAILED` in the logs is **not necessarily a credentials problem**, which is the trap that cost an evening on 03/09: NordVPN retires servers, gluetun only refreshes its embedded server list when `UPDATER_PERIOD` says so, and a retired server that still answers but authorises nobody produces exactly that message. Pull a fresh image before touching any credential.

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
- 01/09/2026: **and the first thing the working monitor reported was a restart nobody had seen**. With the check finally running, the guest's `/proc/uptime` read 25h50m while the QEMU process had been up for seven days: **TrueNAS restarted itself on 30/08 at roughly 21:50 UTC**, and at the time nothing noticed. Precisely the scenario the monitor exists for. The count in this entry originally said "third restart", which the forensics then corrected: **two** spontaneous restarts since the 24/08 fixes, on 29 and 30 August, the earlier boots of the 29th showing no kernel distress and therefore belonging to something outside the guest. The root cause is still open, tracked in `CHECKLIST.md`.
- 01/09/2026: **what the monitor bought, on its first working night**. The restart it reported opened a forensic trail that would not otherwise have been walked, and the trail changed two beliefs. First, the failure of 18-24/08 **is** fixed: the cascades of RCU stalls with `txg_sync` and the `nfsd` threads blocked behind them stopped completely after the 24/08 changes, five days without one. Second, a different failure sits underneath: a single stall, a vCPU halted in `pv_native_safe_halt` waiting for a timer interrupt that never arrived, and an immediate self-restart, twice, in the same three-minute window on consecutive days. A halted vCPU is the hypervisor's responsibility, so this one is not a TrueNAS problem at all. Worth recording here rather than only in `CHECKLIST.md` because it is the argument for the whole document: **the value of an alert is not the notification, it is the question it makes you ask while the evidence is still on disk.** Nobody would have read a guest's boot list from five days earlier without a red monitor pointing at it.
- 03/09/2026: **swap added to the host heartbeat, and a five-second trap built for one specific fault**. `vm.swappiness` was lowered from Debian's default of 60 to 10, because on a hypervisor almost all anonymous memory is guest RAM: on a general-purpose machine trading idle anonymous pages for page cache is a good bargain, but a guest cannot see or compensate for its own pages living on a disk, and roughly 1GB of guest memory was doing exactly that. A host reboot the same day cleared swap entirely, which turned an argument into an experiment: with the heartbeat now carrying `swap=` every minute, Uptime Kuma records on its own whether swap refills once the ARC has grown back. If it stays near zero the swappiness default was the whole problem; if it climbs back past a gigabyte the machine is genuinely short of memory. Either answer is worth more than the opinion it replaces.
- 03/09/2026: **the media stack given a monitor, after ten days of dying unwatched**. `VPN tunnel (gluetun)` is the fifth push check, and choosing what it reads was most of the work. qBittorrent's web interface on port 8080 was the obvious target and would have been a **false green**, because a published port keeps answering with the tunnel down: the kill switch blocks what leaves, not what arrives. gluetun's own control server on port 8000 reports the truth but publishing it would expose an API that can stop the VPN. So the check reads gluetun's health, qBittorrent's state and the public IP gluetun records to a file, all through one `pct exec`, and pushes only when all three hold. The exit IP rides in the message so Uptime Kuma keeps a history of where the downloads were leaving from. **The `|| echo none` on each of the three commands is the part that makes it trustworthy**: without it a failing `docker inspect` prints nothing, three fields become two, and the check starts reading qBittorrent's state as gluetun's health, going green at the moment a container vanishes. Same class of defect as the cron `PATH` bug, and found by asking what the code does when its assumptions fail rather than when they hold.
- 03/09/2026: **stderr moved from a flat file to the journal**, which sounds like tidying and was not. The error log added on 01/09 was already an improvement on `/dev/null`, but its first real use exposed the flaw: eight lines of `ipcc_send_rec failed` with **no timestamps**, so nothing in the file itself said whether this was last night's reboot or a fault in progress. Answering that took the file's mtime. Piping the cron job's stderr through `logger -t monitor-push` gets timestamps, rotation and a single place to look, and on Proxmox 9 the journal is where everything else already is, since `/var/log/syslog` does not exist. **Evidence without a time is barely evidence.**

