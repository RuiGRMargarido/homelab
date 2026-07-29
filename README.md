# HomeLab

Projeto em criacao (v2, Dell OptiPlex 3060 Micro). Este repositorio e, a partir de agora, o local oficial de todo o trabalho deste novo homelab.

No Obsidian, abre este repositorio como vault e comeca por `Homelab.md` — e a nota principal (MOC) com links para tudo o resto.

Contexto detalhado em `docs/PROJECT_CONTEXT.md`.
Checklist de implementação (estado de todas as tarefas): `docs/CHECKLIST.md`.
Esquema lógico de rede (diagrama, VLANs, NICs, regras): `docs/ESQUEMA_LOGICO_REDE.md`.
Shortlist de hardware em `docs/HARDWARE_SHORTLIST.md`.
Ferramentas, documentação (Obsidian), monitorização (Slack) e IaC: `docs/PLANO_FERRAMENTAS_E_BOAS_PRATICAS.md`.
Explicação (para iniciantes) de onde vive cada ferramenta e do fluxo de trabalho: `docs/ARQUITETURA_E_FLUXO_DE_TRABALHO.md`.

Nota: existe uma v1 anterior (PC antigo, TrueNAS + Jellyfin + WireGuard) cuja documentacao ainda vive em `C:\Users\ruigr\codexProjects\HomeLab`, mantida apenas como referencia historica.

## Objetivo
- Construir um homelab para aprender, fazer deploy de projetos e expor 1-2 apps na internet de forma segura.
- Manter custos controlados e permitir crescimento (especialmente storage/RAID).

## Servicos (Fase 1)
- NAS: TrueNAS (VM) com ZFS (sem mirror por agora; RAID mais tarde).
- VPN: WireGuard (administracao remota).
- Reverse proxy: Caddy (TLS automatico) para as apps expostas.
- Cloud: Nextcloud.
- Media server: Jellyfin.

## Arquitetura (Fase 1)
- Router atual + DDNS; expor apenas portas 80/443 para o reverse proxy.
- Proxmox VE no SSD (240GB) como base de VMs/LXCs.
- TrueNAS numa VM com disco(s) dedicados; dados em datasets e partilhas SMB/NFS.
- SSD externo 1TB usado como backup (nao faz parte do RAID).

## Storage (decisao)
- Vamos seguir com backups (nao RAID) para minimizar custos no inicio.

## Estado Atual
- Existiu uma v1 do homelab (PC antigo) com TrueNAS + Jellyfin + WireGuard funcionais. Esta v2 substitui essa maquina.
- Host v2: Dell OptiPlex 3060 Micro (i5-8500T, 16GB, SSD 256GB), 229 EUR.
- Instalado no v2 ate agora: **apenas Proxmox VE**.
- Pendente no v2: TrueNAS (VM), Jellyfin, WireGuard, Nextcloud, Caddy.

## Custos (resumo)
- Fase 1 (sem discos novos): host refurbished i7/32GB tipicamente ~340 a ~420 EUR (depende de stock/loja).
- Fase 2 (quando houver RAID): comprar 2x HDD NAS iguais (ex.: 4TB ou 6TB) e montar ZFS mirror.
- Nota: confirmar precos no momento da compra.

## Hardware (criterios e shortlist)
- Preferencia: torre/MT com 2+ baias 3.5", varias portas SATA, suporte VT-x/VT-d, baixo ruido.
- Exemplo refurb (bom custo/beneficio): Lenovo ThinkCentre M720T (i7-8700, 32GB, NVMe 500GB), ~339,85 EUR (19/02/2026).
- Alternativa refurb: HP EliteDesk 800 G4 (i7-8700, 32GB, SSD 512GB), ~419,00 EUR (19/02/2026).

## Proximos Passos
Checklist completo, com estado (feito/pendente) de todas as fases: `docs/CHECKLIST.md`.
