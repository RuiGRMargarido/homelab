# Hardware Shortlist (host)

Objetivo: host unico para Proxmox + VM TrueNAS, baixo consumo/ruido, com capacidade de crescer (2+ discos 3.5").

## Checklist antes de comprar
- Caixa: torre/MT (preferivel) com 2+ baias 3.5".
- SATA: ideal 4 portas SATA livres (ou 2 livres no minimo para RAID1 futuro).
- M.2/NVMe: desejavel para o disco do Proxmox/VMs (ou SSD SATA).
- RAM: 32GB (ou 16GB com upgrade facil e barato).
- CPU: 6 cores ou mais e suporte VT-x (VT-d desejavel).
- Rede: 1GbE (2.5GbE e bonus, nao obrigatorio na fase 1).
- Ruido: preferir modelos com airflow decente e ventoinhas standard (facil de substituir).

## Opcoes (precos vistos em 19/02/2026)
- HP EliteDesk 800 G5 MT (i7-8700, 32GB, NVMe 500GB): candidato forte para Proxmox + TrueNAS VM.
  - Confirmar antes de comprar: numero de baias 3.5", portas SATA livres, e se vem com caddies/cabos SATA + alimentacao.
  - Pagina: https://www.infocomputerportugal.com/computadores/desktop/segunda-mao/hp-elitedesk-800-g5-mt-core-i7-8700-32-ghz-32-gb-500-nvme-win-11.html
- Lenovo ThinkCentre M720T MT (i7-8700, 32GB, NVMe 500GB): ~339,85 EUR.
  - Pagina: https://www.infocomputerportugal.com/computadores/desktop/segunda-mao/lenovo-thinkcentre-m720t-core-i7-8700-3-20ghz-32gb-500-nvme-win-11.html
- HP EliteDesk 800 G4 (i7-8700, 32GB, 512GB): ~419,00 EUR.
  - Pagina: https://www.worten.pt/produtos/desktop-hp-elitedesk-800-g4-recondicionado-como-novo-intel-core-i7-8700-ram-32gb-512gb-mrkean-7721043142034
- Dell OptiPlex 7070 MT (i7-9700, 32GB, 512GB): ~469,00 EUR (mais caro, mas CPU mais recente).
  - Pagina: https://www.backmarket.pt/pt-pt/p/dell-optiplex-7070-mt-core-i7-9700-32-gb-ssd-512-gb/bc53fe0c-762e-4d81-96ff-a2f0b9bb0a4f

## Mini PC (baixo consumo/ruido; menos expansao de discos)
- Blackview MP100 (Ryzen 5 7430U, 16GB, NVMe 512GB): ~355,00 EUR (PcComponentes, 19/02/2026).
  - Upgrades: tem 2 slots DDR4 e suporta ate 32GB; para chegar a 32GB, somar +1x16GB DDR4-3200 SODIMM (tipicamente +45 a +60 EUR).
  - Pagina: https://www.pccomponentes.com/blackview-mp100-mini-pc-amd-ryzen-5-7430u-16gb-512gb-wifi-6-windows-11-pro
- HP ProDesk 400 G5 Mini (i5-9500T, 32GB, NVMe 256GB): ~389,66 EUR (Infocomputer Portugal, 19/02/2026).
  - Pontos fortes: inclui 32GB e, tipicamente, permite adicionar um disco 2.5" interno (bom para storage sem USB).
  - Pagina: https://www.infocomputerportugal.com/computadores/desktop/segunda-mao/hp-prodesk-400-g5-mini-pc-core-i5-9500t-22-ghz-32-gb-256-nvme-win-11.html

## Escolha atual (host inicial)
- Dell OptiPlex 3060 Micro (i5-8500T, 16GB, SSD 256GB): encomendado por 229 EUR (19/02/2026).
  - Checklist ao receber: confirmar se o SSD e NVMe (M.2) ou SATA; confirmar se a RAM esta em 1x16GB (melhor para upgrade) ou 2x8GB.
  - Upgrades planeados: 32GB RAM quando necessario; SSD maior (512GB/1TB) conforme necessidade.

## Mini PC Refurb (Amazon EU, >= 16GB RAM, <= 250 EUR)
- Nota: eu nao consigo validar links da Amazon a partir deste ambiente; trata isto como criterios/modelos-alvo para filtrar na Amazon Renewed.
- CPU minima recomendada: 4c/8t (ex.: i7-6700T) ou 6c/6t (ex.: i5-8500T) se aparecer dentro do orcamento.
- Modelos que costumo recomendar (procurar variantes com 16GB+ e SSD 256GB+):
  - Dell OptiPlex Micro: 7050/7060/7070 (ideal: i7-6700T ou i5-7500T; melhor ainda i5-8500T se aparecer).
  - HP EliteDesk Mini/DM: 800 G3/G4 (ideal: i5-8500T; minimo aceitavel: i5-6500T com 16GB).
  - Lenovo ThinkCentre Tiny: M710q/M720q (ideal: i5-8500T; minimo aceitavel: i5-6500T com 16GB).
- Filtros praticos: RAM >= 16GB, SSD >= 256GB, vendedor "Amazon Renewed" com boa politica de devolucao.

## Mini PC Novos (>= 16GB RAM)
- Blackview MP80 (Intel N97, 16GB, SSD 512GB, Win 11 Pro): 199,00 EUR (PcComponentes).
  - Pagina: https://www.pccomponentes.pt/blackview-mp80-mini-pc-intel-alder-lake-n97-16gb-512gb-ssd-windows-11-pro
- Huidun H20 (Intel N97, 16GB, SSD 512GB, Win 11 Pro): 225,65 EUR (PcComponentes).
  - Pagina: https://www.pccomponentes.pt/huidun-h20-mini-pc-intel-alder-lake-n97-16gb-512gb-ssd-windows-11-pro
- GEEKOM Air12 Lite 2025 (Intel N150, 16GB, SSD 512GB, Win 11 Pro): 239,99 EUR (PcComponentes).
  - Pagina: https://www.pccomponentes.pt/geekom-air12-lite-2025-mini-pc-intel-processor-n150-16gb-512gb-ssd-windows-11-pro

## Nota sobre discos (para RAID)
- Evitar RAID com discos USB.
- Preferir 2x HDD NAS iguais (ex.: 4TB ou 6TB) ligados por SATA direto.

## Storage (DAS/NAS) para RAID com mini PC
- DAS (USB) 2-bay/4-bay com fonte:
  - Pro: permite RAID/mirror sem trocar de PC.
  - Contra: por ser USB, depende muito da qualidade do hardware/cabos/energia.
  - Exemplo: QNAP TR-002 (2-bay) e um candidato comum.
- NAS dedicado (2-bay):
  - Pro: desenhado para discos 3.5" e RAID; mais "NAS-like".
  - Contra: mais caro e e mais um equipamento ligado 24/7.
  - Exemplo: Synology DS223 (2-bay).

## Backup (opcao escolhida: sem RAID)
- Opcao A (mais simples): HDD externo de escritorio (3.5") pronto a usar, com fonte.
  - Sugestao: 8TB (minimo) para backups completos e crescimento.
  - Ideal (mais seguro): 2 unidades identicas para rotacao (uma ligada, outra guardada/offsite).
- Opcao B (mais flexivel): HDD interno 3.5" + "caixa" USB com fonte (ou adaptador USB-SATA com fonte).
  - Nota: para backups, adaptador USB-SATA com fonte funciona bem e e mais barato; para uso permanente, uma caixa fechada e melhor.

## Exemplos (links)
- WD Elements Desktop 8TB (HDD externo pronto a usar): https://www.pcmadrid.es/discos-duros/215070-wd-elements-8tb-usb-30-negro.html
- Toshiba N300 6TB (HDD interno NAS): https://www.pccomponentes.pt/toshiba-nas-n300-35-6tb-sata-3
- UGREEN USB <-> SATA + 12V/2A (adaptador com fonte): https://www.amazon.es/dp/B00MYU0EAU
- Inateck FE3002 (caixa 3.5" com fonte): https://www.idealo.de/preisvergleich/OffersOfProduct/202541873_-fe3002-inateck.html
