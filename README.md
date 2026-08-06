# HomeLab

Projeto em criacao (v2, Dell OptiPlex 3060 Micro). Este repositorio e, a partir de agora, o local oficial de todo o trabalho deste novo homelab.

No Obsidian, abre este repositorio como vault e comeca por `Homelab.md` - e a nota principal (MOC) com links para tudo o resto.

Contexto detalhado em `docs/PROJECT_CONTEXT.md`.
Checklist de implementação (estado de todas as tarefas): `docs/CHECKLIST.md`.
Esquema lógico de rede (estado atual vs alvo, VLANs, regras, caminhos de pacote): `docs/ESQUEMA_LOGICO_REDE.md`.
Esquema de dados e storage (ZFS, NFS, bind mounts, backup): `docs/ESQUEMA_DADOS_E_STORAGE.md`.
Shortlist de hardware em `docs/HARDWARE_SHORTLIST.md`.
Ferramentas, documentação (Obsidian), monitorização (Slack) e IaC: `docs/PLANO_FERRAMENTAS_E_BOAS_PRATICAS.md`.
Explicação (para iniciantes) de onde vive cada ferramenta e do fluxo de trabalho: `docs/ARQUITETURA_E_FLUXO_DE_TRABALHO.md`.

Nota: existe uma v1 anterior (PC antigo, TrueNAS + Jellyfin + WireGuard) cuja documentacao ainda vive em `C:\Users\ruigr\codexProjects\HomeLab`, mantida apenas como referencia historica.

## Objetivo
- Construir um homelab para aprender, fazer deploy de projetos e expor 1-2 apps na internet de forma segura.
- Manter custos controlados e permitir crescimento (especialmente storage/RAID).

## Servicos
- NAS: TrueNAS (VM) com ZFS (sem mirror por agora; RAID mais tarde).
- VPN: WireGuard (administracao remota, acesso a zona Trusted).
- Reverse proxy: Caddy (TLS automatico) - por agora so HTTPS interno via WireGuard; ganha exposicao publica quando houver uma app decidida (ver Pendencias).
- Cloud: Nextcloud (so via WireGuard, sem exposicao publica).
- Media server: Jellyfin (so via WireGuard).

## Arquitetura
- Router atual + DDNS; o port-forward aponta para uma VM de firewall dedicada, que media o trafego entre zonas de rede (VLANs) - detalhe completo em `docs/ESQUEMA_LOGICO_REDE.md`.
- Proxmox VE no SSD (240GB) como base de VMs/LXCs. Os servicos de aplicacao correm hoje em LXCs com Docker Compose; a migracao para um cluster k3s esta planeada para a Fase 4.
- TrueNAS numa VM com disco(s) dedicados; dados em datasets e partilhas SMB/NFS.
- SSD externo 1TB usado como backup (nao faz parte do RAID).

## Storage (decisao)
- Vamos seguir com backups (nao RAID) para minimizar custos no inicio.

## Estado Atual (06/08/2026)
- Existiu uma v1 do homelab (PC antigo, atualmente desligado) com TrueNAS + Jellyfin + WireGuard funcionais. Esta v2 substitui essa maquina.
- Host v2: Dell OptiPlex 3060 Micro (i5-8500T, 16GB, SSD 256GB), 229 EUR. **Upgrade para 32GB ainda por fazer.**
- **Fase 1 (servicos base) concluida**: Proxmox VE, TrueNAS (VM 102), WireGuard (LXC 103), Caddy (LXC 101), Nextcloud (LXC 104), Jellyfin (LXC 105) - todos a correr. Backup automatizado para SSD externo, com restore testado e validado.
- **Fase 2 (VLANs + firewall) em curso**: VLANs 10/20/30 criadas no switch e no Proxmox, VM de firewall dedicada a correr (OPNsense, VM 106). WireGuard ja migrado para a DMZ e o proprio Proxmox ja tem interface na zona Management. **Falta migrar** TrueNAS, Caddy, Nextcloud e Jellyfin para a zona Trusted - continuam na rede plana.
- Fases 3 a 6 (RAID, IaC/k3s, monitorizacao, Obsidian): por comecar.

Estado detalhado, tarefa a tarefa: `docs/CHECKLIST.md`. Criterios e opcoes de hardware consideradas (incluindo as alternativas nao escolhidas e estimativas de custo do RAID futuro): `docs/HARDWARE_SHORTLIST.md` e `docs/PROJECT_CONTEXT.md`.

## Proximos Passos
Checklist completo, com estado (feito/pendente) de todas as fases: `docs/CHECKLIST.md`.
