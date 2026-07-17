# Project Context: HomeLab

Documento de contexto vivo do projeto. Atualizar quando houver decisoes novas.

## Snapshot (19/02/2026, atualizado 18/07/2026)
- Objetivo: aprender e fazer deploy de projetos num homelab com exposicao externa controlada (1-2 apps).
- Decidido: Proxmox VE + TrueNAS (VM) + Caddy + WireGuard + Nextcloud + Jellyfin.
- Decidido: comprar um mini PC como host inicial (baixo consumo/ruido).
- Storage atual: 1x HDD 1TB (3.5") + 1x SSD 240GB; existe tambem 1x SSD externo 1TB (para backup).

## Historico: v1 (PC antigo) vs v2 (OptiPlex, atual)
- **v1 (PC antigo)**: primeira versao do homelab, ja tinha TrueNAS, Jellyfin e WireGuard instalados e funcionais (DDNS proprio, Jellyfin acessivel na rede local e remotamente via WireGuard). Havia tambem uma stack de IA/RAG em Docker (Open WebUI + Ollama + Qdrant) a correr nesta v1.
- **v2 (Dell OptiPlex 3060 Micro, em curso)**: novo homelab, a substituir a v1. Estado atual real: **apenas o Proxmox VE esta instalado**. TrueNAS (VM), Jellyfin, WireGuard, Nextcloud, Caddy e a stack RAG ainda **nao foram (re)criados** no novo host.

## Objetivos
- Construir um homelab com custos controlados e baixo consumo/ruido.
- Ter NAS, media server, cloud pessoal, VPN e reverse proxy.
- Permitir crescimento futuro (especialmente storage/RAID, servicos e seguranca).

## Escopo
- Inclui: hardware base, servicos faseados, exposicao externa segura, plano de evolucao.
- Nao inclui (por agora): arquitetura detalhada de rede com VLANs/firewall dedicado.

## Servicos (Fase 1)
- NAS: TrueNAS (VM) com ZFS.
- VPN: WireGuard para administracao remota.
- Reverse proxy: Caddy com TLS automatico para apps expostas.
- Cloud: Nextcloud.
- Media: Jellyfin.

## Arquitetura (alto nivel)
- Router atual com DDNS; port-forward apenas 80/443 para o reverse proxy.
- Host unico com Proxmox VE no SSD (240GB).
- TrueNAS em VM com disco(s) dedicados e datasets para `apps`, `cloud`, `media`, `backups`.
- Apps em VMs/LXCs (ou containers) com dados persistidos no TrueNAS.
- Administracao remota via VPN; evitar expor interfaces de admin na internet.

## Dados (RAID vs backup)
- RAID (ex.: ZFS mirror) protege contra falha de disco, mas nao substitui backup.
- Fase 1: sem RAID (usar discos existentes) + backup para SSD externo 1TB.
- Fase 2: comprar 2x HDD NAS iguais e migrar para ZFS mirror (RAID1).

## RAID com Mini PC (opcoes praticas)
- Melhor (mais robusto): migrar storage para um host com discos SATA internos (torre) ou usar um NAS dedicado.
- Se ficar no mini PC: usar um DAS 2-bay/4-bay com fonte e boa controladora USB (evitar RAID/ZFS em caixas USB baratas).
- Evitar: montar ZFS/RAID em discos USB instaveis; USB e aceitavel para backups, mas para RAID requer hardware decente e cabos/energia confiaveis.

## Estimativa de custo (referencia)
- DAS 2-bay (ex.: QNAP TR-002) + 2x HDD NAS 6TB:
  - TR-002: ~174 EUR.
  - 2x 6TB: ~350 EUR (dependendo do modelo).
  - Total esperado: ~525 EUR (sem contar com eventuais portes).
- NAS dedicado 2-bay (ex.: Synology DS223) + 2x HDD NAS 6TB:
  - DS223 (sem discos): ~279 EUR.
  - 2x 6TB: ~350 EUR (dependendo do modelo).
  - Total esperado: ~630 EUR.

## Decisao: backups em vez de RAID (para minimizar custos)
- Opcao escolhida: nao implementar RAID por agora; usar backups (com pelo menos 2 copias) para reduzir custo.
- Recomendacao pratica:
  - 1x SSD externo (1TB) para "backup rapido" de dados criticos.
  - 1x HDD externo grande (8TB+) para backups completos.
  - Opcional (mais seguro): 2o HDD externo grande para rotacao/offsite.

## Backup (hardware recomendado e custos)
- Opcao A (mais simples/normalmente mais barata): 1-2x HDD externo de escritorio (3.5") pronto a usar.
  - Exemplo: WD Elements Desktop 8TB: ~194 EUR (preco referencia EU em 19/02/2026).
- Opcao B (HDD interno + caixa USB com fonte): boa se quiseres escolher o modelo do disco.
  - Exemplo: Toshiba N300 6TB + adaptador USB-SATA com fonte:
    - N300 6TB: ~204,50 EUR.
    - Adaptador UGREEN USB 3.0 <-> SATA + 12V/2A: ~20,79 EUR.
    - Total: ~225,29 EUR (1 disco).

## Links (exemplos)
- WD Elements Desktop 8TB (exemplo loja): https://www.pcmadrid.es/discos-duros/215070-wd-elements-8tb-usb-30-negro.html
- Toshiba N300 6TB (exemplo loja): https://www.pccomponentes.pt/toshiba-nas-n300-35-6tb-sata-3
- UGREEN USB <-> SATA + 12V/2A (Amazon.es): https://www.amazon.es/dp/B00MYU0EAU
- Inateck FE3002 (caixa 3.5" com fonte, referencia): https://www.idealo.de/preisvergleich/OffersOfProduct/202541873_-fe3002-inateck.html

## Como vamos usar os discos (backup vs principal)
- Disco A: armazenamento principal (dados "vivos" na NAS).
- Disco B: destino de backup (copias agendadas do Disco A).
- Boa pratica: rotacao/offsite (ex.: desligar e guardar o Disco B apos o backup) para reduzir risco de ransomware/erro humano.
- Backups devem ter historico/retencao (versionamento) e restores devem ser testados periodicamente.

## Hardware (requisitos)
- Preferencia: torre/MT com 2+ baias 3.5" e varias portas SATA (para RAID e expansao).
- CPU: Intel com VT-x (idealmente com VT-d); i7 8th gen e um bom equilibrio para Proxmox.
- RAM: 32GB (TrueNAS + apps) com possibilidade de upgrade.
- Ruido/consumo: priorizar PSU eficiente e ventoinhas silenciosas.

## Hardware (shortlist e precos)
- Refurb (candidato): HP EliteDesk 800 G5 MT (i7-8700, 32GB, NVMe 500GB), Infocomputer Portugal (19/02/2026).
  - Confirmar: baias 3.5", portas SATA livres, e caddies/cabos SATA inclusos.
- Refurb (bom custo/beneficio): Lenovo ThinkCentre M720T MT (i7-8700, 32GB, NVMe 500GB) por ~339,85 EUR (Infocomputer Portugal, 19/02/2026).
- Refurb (alternativa): HP EliteDesk 800 G4 (i7-8700, 32GB, SSD 512GB) por ~419,00 EUR (Worten PT, 19/02/2026).
- Nota: confirmar disponibilidade e caracteristicas (baias 3.5", SATA, PSU) antes de comprar.

## Opcao alternativa: Mini PC (sem RAID interno)
- Se a prioridade for baixo consumo/ruido e o RAID interno nao for requisito imediato, um mini PC pode ser suficiente.
- Limites: menos expansao para discos 3.5"; storage adicional tende a ser via SSD interno (se houver slot) ou USB/DAS.
- Exemplos e links em `docs/HARDWARE_SHORTLIST.md`.

## Orcamento e compras por fases
- Fase 1 (agora): comprar apenas o host; reutilizar HDD/SSD existentes; usar SSD externo como backup.
- Fase 2 (RAID): comprar 2x HDD NAS iguais (4TB ou 6TB) e montar ZFS mirror; manter backups.
- Fase 3 (opcional): firewall dedicado/VLANs, mais discos, automacao (IaC), monitorizacao.

## Plano de instalacao (resumo)
1. Instalar Proxmox VE no SSD 240GB.
2. Criar VM TrueNAS e passar o HDD 1TB (passthrough de disco).
3. Criar datasets e partilhas (SMB/NFS) no TrueNAS.
4. Criar WireGuard e Reverse proxy (Caddy).
5. Criar Nextcloud e Jellyfin e ligar storage ao TrueNAS.
6. Configurar DDNS e port-forward 80/443 no router (apenas para o reverse proxy).
7. Automatizar backups para SSD externo e testar restore.

## Riscos e mitigacoes
- Exposicao externa insegura: usar reverse proxy + TLS + limitar portas + admin via VPN.
- Perda de dados (sem RAID): backups frequentes + teste de restores; migrar para RAID quando possivel.
- Crescimento limitado: escolher host com baias/SATA; planear fases.

## Pendencias
- Instalar VM TrueNAS no Proxmox (v2) e migrar/recriar datasets.
- Recriar Jellyfin e WireGuard no novo host (v2); confirmar se DDNS sera o mesmo dominio da v1 ou novo.
- Decidir se a stack RAG (Open WebUI + Ollama + Qdrant) da v1 sera recriada no v2 e em que fase.
- Definir estrategia de backup (frequencia, retencao e copia fora de casa).
- Confirmar destino/desligamento do PC antigo (v1) apos migracao (evitar perda de dados antes de confirmar que o v2 esta operacional).

## Decisoes recentes
- 19/02/2026: host escolhido e encomendado: Dell OptiPlex 3060 Micro (i5-8500T, 16GB RAM, SSD 256GB) por 229 EUR.
  - Motivo: melhor custo/beneficio dentro do budget e baixo consumo/ruido.
  - Plano de upgrades: 32GB RAM quando necessario; SSD maior (512GB/1TB) quando o storage apertar.
- 18/07/2026: confirmado que o Proxmox VE ja esta instalado no OptiPlex (v2); restantes servicos (TrueNAS, Jellyfin, WireGuard) ainda por instalar nesta nova maquina.

## Historico
- 19/02/2026: criado e consolidado contexto inicial, servicos e plano por fases.
- 19/02/2026: decidido host inicial (Dell OptiPlex 3060 Micro) e definido plano ao receber o equipamento.
- (data anterior, PC antigo): v1 do homelab operacional com TrueNAS + Jellyfin + WireGuard + stack RAG (Open WebUI/Ollama/Qdrant) em Docker.
- 18/07/2026: consultada conversa historica do ChatGPT sobre a v1 (media/streaming/VPN) e confirmado com o utilizador que essa conversa descreve a v1, nao o estado atual do v2. Docs atualizados para refletir que o v2 tem, por agora, apenas o Proxmox instalado.
