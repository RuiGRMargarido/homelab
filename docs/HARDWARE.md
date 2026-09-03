# Hardware Shortlist (host)

Goal: a single host for Proxmox + a TrueNAS VM, low power draw and low noise, with room to grow (2+ 3.5" drives).

## Checklist before buying
- Case: tower/MT (preferred) with 2+ 3.5" bays.
- SATA: ideally 4 free SATA ports (2 free at minimum, for a future RAID1).
- M.2/NVMe: desirable for the Proxmox/VM disk (or a SATA SSD).
- RAM: 32GB (or 16GB with a cheap, easy upgrade path).
- CPU: 6 cores or more, with VT-x support (VT-d desirable).
- Network: 1GbE (2.5GbE is a bonus, not required for phase 1).
- Noise: prefer models with decent airflow and standard fans (easy to replace).

## Options (prices seen on 19/02/2026)
- HP EliteDesk 800 G5 MT (i7-8700, 32GB, 500GB NVMe): strong candidate for Proxmox + a TrueNAS VM.
  - Confirm before buying: number of 3.5" bays, free SATA ports, and whether caddies/SATA cables + power come included.
  - Page: https://www.infocomputerportugal.com/computadores/desktop/segunda-mao/hp-elitedesk-800-g5-mt-core-i7-8700-32-ghz-32-gb-500-nvme-win-11.html
- Lenovo ThinkCentre M720T MT (i7-8700, 32GB, 500GB NVMe): ~EUR 339.85.
  - Page: https://www.infocomputerportugal.com/computadores/desktop/segunda-mao/lenovo-thinkcentre-m720t-core-i7-8700-3-20ghz-32gb-500-nvme-win-11.html
- HP EliteDesk 800 G4 (i7-8700, 32GB, 512GB): ~EUR 419.00.
  - Page: https://www.worten.pt/produtos/desktop-hp-elitedesk-800-g4-recondicionado-como-novo-intel-core-i7-8700-ram-32gb-512gb-mrkean-7721043142034
- Dell OptiPlex 7070 MT (i7-9700, 32GB, 512GB): ~EUR 469.00 (pricier, but a newer CPU).
  - Page: https://www.backmarket.pt/pt-pt/p/dell-optiplex-7070-mt-core-i7-9700-32-gb-ssd-512-gb/bc53fe0c-762e-4d81-96ff-a2f0b9bb0a4f

## Mini PC (low power and noise; less room for drives)
- Blackview MP100 (Ryzen 5 7430U, 16GB, 512GB NVMe): ~EUR 355.00 (PcComponentes, 19/02/2026).
  - Upgrades: two DDR4 slots, supports up to 32GB; reaching 32GB means adding 1x16GB DDR4-3200 SODIMM (typically +EUR 45 to 60).
  - Page: https://www.pccomponentes.com/blackview-mp100-mini-pc-amd-ryzen-5-7430u-16gb-512gb-wifi-6-windows-11-pro
- HP ProDesk 400 G5 Mini (i5-9500T, 32GB, 256GB NVMe): ~EUR 389.66 (Infocomputer Portugal, 19/02/2026).
  - Strengths: 32GB included and, typically, room for an internal 2.5" drive (useful for storage without USB).
  - Page: https://www.infocomputerportugal.com/computadores/desktop/segunda-mao/hp-prodesk-400-g5-mini-pc-core-i5-9500t-22-ghz-32-gb-256-nvme-win-11.html

## Current choice (initial host)
- Dell OptiPlex 3060 Micro (i5-8500T, 16GB, 256GB SSD): ordered for EUR 229 (19/02/2026).
  - Checklist on arrival: ~~confirm whether the SSD is NVMe (M.2) or SATA; confirm whether the RAM is 1x16GB or 2x8GB~~ - both answered, see below.
  - Planned upgrades: 32GB RAM when needed; a larger SSD (512GB/1TB) as storage demands.

### Measured configuration (03/09/2026, from `dmidecode` and `lsblk`)

Read off the machine rather than off the listing, because two of these answers changed a purchasing decision.

| | |
|---|---|
| CPU | i5-8500T, 6 cores, **6 threads** (no HyperThreading), max 4.2GHz |
| RAM ceiling | **32GB**, 2 slots (`Physical Memory Array / Maximum Capacity`) |
| RAM fitted | **2x8GB** DDR4-2666 SODIMM, Micron `8ATF1G64HZ-2G6E1`, one rank each |
| BIOS | Dell 1.2.17, **dated 09/10/2018**, never updated |
| Microcode | `0xfa`, loaded at boot by Debian's `intel-microcode` package (2025-08-12), **not** by the 2018 BIOS |
| M.2 slots | `SLOT1_M.2` (Socket 3, x4) holds the NVMe; `SLOT2_M.2` (Socket 1-SD, x1) holds the WiFi card |
| SATA | `SATA0` present on the board and **free**, but only fits a 2.5" drive |
| TPM | 2.0 (Nuvoton) |

Disks, with their transport, which is the detail that matters here:

| Device | Size | Type | Transport | Model |
|---|---|---|---|---|
| `nvme0n1` | 238.5G | SSD | **NVMe** | Samsung PM981 |
| `sdb` | 931.5G | HDD | **USB** | WDC WD10EZEX-08M2NA0 (the ZFS pool) |
| `sda` | 931.5G | SSD | **USB** | SanDisk Portable SSD (backups) |

### Buying the 32GB upgrade (prices checked 03/09/2026, and they are moving fast)

**Specification to match**: SODIMM DDR4, 260-pin, 16GB per module, 2666 MT/s or faster (3200 modules downclock cleanly to 2666), non-ECC, unbuffered, 1.2V. Both slots are occupied by 8GB modules, so 32GB means replacing both.

**The market context matters more than any single price here.** DDR4 is in a severe shortage: kits that cost around USD 50 in early 2025 were selling for USD 150 to 240 by February 2026, SODIMM DDR4 prices are up 277% to 380% since Q1 2025, and Micron has issued end-of-life notices across most of its DDR4 range as manufacturers shift capacity to DDR5 and server memory for AI infrastructure. Forecasts point to further monthly rises through the end of 2026 and shortage conditions into Q4 2027. **The upgrade now costs about what the whole machine cost** (EUR 229, February 2026), which inverts the usual assumption that RAM is the cheap lever.

| Option | Result | Price | Where |
|---|---|---|---|
| 1x16GB used, keeping one 8GB | **24GB** | ~EUR 65 to 80 | [OLX Portugal](https://www.olx.pt/tecnologia-e-informatica/q-16gb-ddr4-sodimm/) |
| 1x16GB new, keeping one 8GB | **24GB** | EUR 113.98 (Apacer ES.16G21.PSH) | [PcComponentes, 16GB SODIMM DDR4](https://www.pccomponentes.pt/memorias-ram/16-gb/so-dimm/ddr4) |
| 2x16GB new, two single modules | 32GB | ~EUR 228 | same listing as above |
| 2x16GB new, matched kit | 32GB | EUR 276.99 (Crucial CT2K16G4SFRA32A) | [PcComponentes](https://www.pccomponentes.pt/crucial-so-dimm-ddr4-3200mhz-pc4-25600-32-gb-2x16-gb-cl22) |
| Other 32GB kits | 32GB | EUR 243 to 313 (Kingston, Corsair, G.Skill) | [PcComponentes, 32GB SODIMM](https://www.pccomponentes.pt/memorias-ram/32-gb/so-dimm) |

**Two traps in that table.** On the used market, most listings advertised as "16GB" are actually **2x8GB kits**, which are worthless here because that is exactly what is already fitted; the search has to be for a *single* 16GB module. And in the 32GB listings, entries like the Crucial `CT32G4SFD832A` are **single 32GB modules**, not kits: one of those reaches 32GB in a single slot but leaves the machine in single channel, halving memory bandwidth on a host running several VMs.

**24GB is a real option and probably the right one.** Flex Mode runs the matching 8GB in dual channel and the remainder single channel, which is an ordinary laptop configuration. With ~23.4GB usable: TrueNAS 8, OPNsense 3, containers 1, host 1, leaving about 10GB. That ends the swapping, fits k3s and fits a standalone Prometheus. The only thing it does not fit is also bringing the development VM home, which is precisely what the extra 8GB of a full 32GB buys.

**Neither USB disk can move to the free SATA0 port.** The `WD10EZEX` is a 3.5" desktop drive and the 3060 Micro only accepts 2.5"; the SanDisk is a sealed portable unit, not a caddy. Using SATA0 means buying a 2.5" drive. One piece of good news: the `WD10EZEX` is **CMR, not SMR**, which for ZFS matters a great deal. The disk is not a bad one, it is badly placed.

### What was actually bought (03/09/2026)

**Apacer `ES.16G21.PSH`**, 16GB SODIMM DDR4-3200 CL22, non-ECC, unbuffered, 1.2V, 30mm, **EUR 113.99** from PcComponentes with free returns. Fitted beside one of the existing 8GB modules it gives **24GB**, and the second 8GB module is kept as a spare, which is worth more than usual in this market.

Every line was checked against what the machine reports about itself rather than the seller's description:

| The machine requires | The module provides |
|---|---|
| SODIMM, 260-pin | SO-DIMM, 260-pin |
| DDR4 | DDR4 |
| 2666 MT/s or faster | 3200, downclocks to 2666 |
| **Non-ECC** (`Total Width` = `Data Width` = 64 bits) | Non-ECC |
| Unbuffered | Unbuffered |
| 1.2V | 1.2V |
| **One 16GB module, not a 2x8GB kit** | Single 16GB module |
| 30mm height (the chassis is tight) | 30mm, no heat spreader |

**The specification is readable off the machine itself.** `dmidecode -t memory` answers every row above, and the row people miss is `Total Width` against `Data Width`: 72 against 64 means ECC, 64 against 64 means not. Free returns are worth the premium over the used market here, because a module that fails `memtest86+` can go back.

**Before trusting new memory, test it.** `memtest86+` is in the Proxmox GRUB menu; one full pass is the minimum. Bad RAM on a hypervisor corrupts guest data silently, and on a ZFS pool that surfaces weeks later as checksum errors with no obvious cause. Then confirm both slots are seen at the expected speed with `dmidecode -t memory`, and if the machine will not POST at all, swap the modules between slots: mixed-size configurations make some BIOSes fussy about which goes where, and this one has never been updated since 2018.

### Used mini PCs with 32GB, surveyed 03/09/2026

Searched because in a memory shortage the question is worth asking backwards: if modules cost nearly as much as a machine, buy the machine.

**The finding was the absence.** Across the Portuguese used market, **no business-class mini PC with 32GB exists**: zero OptiPlex Micro and zero ThinkCentre Tiny above 16GB. That follows from the shortage, since anyone selling one pulls the modules first. So a machine cannot be bought as a disguised memory upgrade.

For reference, what this machine is now worth and what its peers cost:

| | Price |
|---|---|
| OptiPlex 3060 Micro, i5-8500T, 8GB, 256GB (OLX) | EUR 140 to 155 |
| ThinkCentre M920q, i5-8500T, 16GB, 256GB (OLX) | EUR 269 |
| OptiPlex 7060 Micro, i5-8500T, 16GB (retailer) | EUR 309.84 |

The machines that do carry 32GB are all modern consumer mini PCs. The one worth recording is the **Minisforum Venus NAB5** at EUR 529: i5-12450H (8C/12T), 32GB DDR4 with a **64GB ceiling**, 1TB PCIe 4.0, **dual 2.5GbE**, and Intel UHD graphics so QuickSync survives. That combination would close four items at once, since it doubles the memory ceiling, replaces the 256GB SSD, removes the USB-RJ45 adapter that sits in the risk list, and frees the 3060 to become the development machine.

**Three candidates were eliminated for reasons worth keeping.** A Zotac Magnus One at EUR 650 carries an `i5-10400F`, and the `F` means no integrated graphics, which would destroy the QuickSync transcoding Jellyfin depends on. A Mac mini 2018 with 32GB at EUR 420 has the T2 chip, making Proxmox an unsupported fight. And a Ryzen 5 7430U machine at EUR 395 is good hardware, but AMD graphics mean rebuilding hardware transcoding on VAAPI instead of QuickSync.

**Not bought**, and the reasoning is in `CHECKLIST.md`: it is consumer hardware for a 24/7 data role where the current machine has never once failed at the hardware level, it is a private used sale with no recourse, the migration would repeat the interface-renaming and passthrough work of 24/08, and swapping hardware in the middle of an open fault investigation guarantees never learning the cause.

## Refurbished mini PCs (Amazon EU, >= 16GB RAM, <= EUR 250)
- Note: Amazon links cannot be validated from this environment; treat this as criteria and target models to filter by on Amazon Renewed.
- Minimum recommended CPU: 4c/8t (e.g. i7-6700T) or 6c/6t (e.g. i5-8500T) if one shows up within budget.
- Models usually worth recommending (look for variants with 16GB+ and a 256GB+ SSD):
  - Dell OptiPlex Micro: 7050/7060/7070 (ideal: i7-6700T or i5-7500T; better still, i5-8500T if available).
  - HP EliteDesk Mini/DM: 800 G3/G4 (ideal: i5-8500T; acceptable minimum: i5-6500T with 16GB).
  - Lenovo ThinkCentre Tiny: M710q/M720q (ideal: i5-8500T; acceptable minimum: i5-6500T with 16GB).
- Practical filters: RAM >= 16GB, SSD >= 256GB, "Amazon Renewed" seller with a good returns policy.

## New mini PCs (>= 16GB RAM)
- Blackview MP80 (Intel N97, 16GB, 512GB SSD, Win 11 Pro): EUR 199.00 (PcComponentes).
  - Page: https://www.pccomponentes.pt/blackview-mp80-mini-pc-intel-alder-lake-n97-16gb-512gb-ssd-windows-11-pro
- Huidun H20 (Intel N97, 16GB, 512GB SSD, Win 11 Pro): EUR 225.65 (PcComponentes).
  - Page: https://www.pccomponentes.pt/huidun-h20-mini-pc-intel-alder-lake-n97-16gb-512gb-ssd-windows-11-pro
- GEEKOM Air12 Lite 2025 (Intel N150, 16GB, 512GB SSD, Win 11 Pro): EUR 239.99 (PcComponentes).
  - Page: https://www.pccomponentes.pt/geekom-air12-lite-2025-mini-pc-intel-processor-n150-16gb-512gb-ssd-windows-11-pro

## A note on disks (for RAID)
- Avoid RAID on USB-attached disks.
- Prefer 2x identical NAS HDDs (e.g. 4TB or 6TB) connected over plain SATA.

## Storage (DAS/NAS) for RAID with a mini PC
- DAS (USB), 2-bay/4-bay with its own power supply:
  - Pro: allows RAID/mirroring without changing the host.
  - Con: being USB, it depends heavily on the quality of the hardware, cables and power.
  - Example: the QNAP TR-002 (2-bay) is a common candidate.
- Dedicated NAS (2-bay):
  - Pro: designed for 3.5" drives and RAID; more "NAS-like".
  - Con: more expensive, and one more device running 24/7.
  - Example: Synology DS223 (2-bay).

## Backup (chosen option: no RAID)
- Option A (simplest): a desktop-class external HDD (3.5"), ready to use, with its own power supply.
  - Suggestion: 8TB (minimum) for full backups plus growth.
  - Ideal (safest): two identical units on rotation (one connected, one stored offsite).
- Option B (more flexible): an internal 3.5" HDD plus a powered USB enclosure (or a powered USB-SATA adapter).
  - Note: for backups, a powered USB-SATA adapter works well and is cheaper; for permanent use, a proper enclosure is better.

## Examples (links)
- WD Elements Desktop 8TB (ready-to-use external HDD): https://www.pcmadrid.es/discos-duros/215070-wd-elements-8tb-usb-30-negro.html
- Toshiba N300 6TB (internal NAS HDD): https://www.pccomponentes.pt/toshiba-nas-n300-35-6tb-sata-3
- UGREEN USB <-> SATA + 12V/2A (powered adapter): https://www.amazon.es/dp/B00MYU0EAU
- Inateck FE3002 (powered 3.5" enclosure): https://www.idealo.de/preisvergleich/OffersOfProduct/202541873_-fe3002-inateck.html
