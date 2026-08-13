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
  - Checklist on arrival: confirm whether the SSD is NVMe (M.2) or SATA; confirm whether the RAM is 1x16GB (better for upgrading) or 2x8GB.
  - Planned upgrades: 32GB RAM when needed; a larger SSD (512GB/1TB) as storage demands.

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
