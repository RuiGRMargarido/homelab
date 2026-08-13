# Project Context: HomeLab

Documento de contexto vivo do projeto. Atualizar quando houver decisoes novas.

## Snapshot (19/02/2026, atualizado 06/08/2026)
- Objetivo: aprender e fazer deploy de projetos num homelab com exposicao externa controlada (1-2 apps).
- Decidido: Proxmox VE + TrueNAS (VM) + Caddy + WireGuard + Nextcloud + Jellyfin.
- **Fase 1 (servicos base) concluida e validada** - todos os servicos acima a correr, mais backup automatizado com restore testado.
- **Fase 2 (VLANs + firewall) em curso** - VLANs 10/20/30 ativas, OPNsense (VM 106) a mediar as zonas, WireGuard ja na DMZ, Proxmox ja com interface na Management. Falta migrar TrueNAS/Caddy/Nextcloud/Jellyfin para a Trusted (continuam na rede plana).
- Storage atual: 1x HDD 1TB (3.5", em bay USB TooQ, pool ZFS `tank_test` da NAS antiga ja importada) + 1x SSD 240GB (Proxmox); mais 1x SSD externo 1TB, formatado exFAT, em uso como destino de backup diario.
- RAM atual: 16GB (upgrade para 32GB ainda por fazer). Ver "Riscos e mitigacoes" - o total ja *configurado* entre VMs/LXCs excede os 16GB fisicos.
- Rede: arquitetura de VLANs + firewall dedicada decidida (22/07/2026) - ver seccao "Rede e Segmentacao". Switch TL-SG608E e gerido, com suporte a VLAN 802.1Q.
- Ordem de construcao (decidida 29/07/2026): servicos base primeiro (rede simples), VLANs/firewall dedicada depois - ver seccao "Ordem de construcao".
- VM de desenvolvimento (28/07/2026, confirmada 02/08/2026): VM 100 `mnt-mate` (Linux Mint), para programar e testar agentes/LLMs - zona de rede ainda por decidir, ver "Ambiente de desenvolvimento" e Pendencias.

## Historico: v1 (PC antigo) vs v2 (OptiPlex, atual)
- **v1 (PC antigo)**: primeira versao do homelab, ja tinha TrueNAS, Jellyfin e WireGuard instalados e funcionais (DDNS proprio, Jellyfin acessivel na rede local e remotamente via WireGuard). Havia tambem uma stack de IA/RAG em Docker (Open WebUI + Ollama + Qdrant) a correr nesta v1.
- **v2 (Dell OptiPlex 3060 Micro, em curso)**: novo homelab, a substituir a v1. Estado atual (06/08/2026): Proxmox VE, TrueNAS (VM 102), WireGuard (LXC 103), Caddy (LXC 101), Nextcloud (LXC 104) e Jellyfin (LXC 105) **criados e a funcionar**, mais a VM de firewall OPNsense (106) e a VM de desenvolvimento `mnt-mate` (100). A stack RAG (Open WebUI + Ollama + Qdrant) da v1 **nao foi recriada** - continua por decidir se volta, ver Pendencias.

## Objetivos
- Construir um homelab com custos controlados e baixo consumo/ruido.
- Ter NAS, media server, cloud pessoal, VPN e reverse proxy.
- Permitir crescimento futuro (especialmente storage/RAID, servicos e seguranca).
- Ambiente de desenvolvimento: VM Linux para programar e testar agentes/LLMs (28/07/2026).

## Escopo
- Inclui: hardware base, servicos faseados, exposicao externa segura, plano de evolucao, arquitetura de rede com VLANs e firewall dedicado (decidido 22/07/2026 - ver seccao "Rede e Segmentacao").
- Nao inclui (por agora): mais zonas/VLANs alem das 3 definidas (DMZ/Trusted/Management); alta disponibilidade (multi-host); segmentacao Wi-Fi/guest/IoT da rede domestica geral (28/07/2026: decidido manter independente do OptiPlex, ver "Router de casa e rede domestica").

## Servicos (Fase 1)
- NAS: TrueNAS (VM) com ZFS. Zona: Trusted.
- VPN: WireGuard para administracao remota - ponto de entrada para a zona Trusted a partir da internet. Zona: DMZ (perna internet-facing); atribui IPs aos clientes autenticados numa subnet propria (tunel).
- Reverse proxy: Caddy - por agora so serve HTTPS interno (Nextcloud/Jellyfin) para quem ja esta ligado por WireGuard. Zona: Trusted. So ganha uma perna em DMZ quando houver uma app decidida para exposicao publica (ver Pendencias).
- Cloud: Nextcloud - decidido (22/07/2026) ficar so interno, sem exposicao publica; acesso exclusivamente via WireGuard. Zona: Trusted.
- Media: Jellyfin - mesmo padrao da v1 (so acesso remoto via WireGuard). Zona: Trusted.

## Arquitetura (alto nivel)
- Router atual com DDNS; port-forward (80/443 quando houver app exposta; porta UDP do WireGuard) aponta para a perna WAN-side da VM de firewall - nao diretamente para os servicos.
- Host unico com Proxmox VE no SSD (240GB).
- VM de firewall dedicada (tipo OPNsense/pfSense) media todo o trafego entre zonas - ver "Rede e Segmentacao (VLANs + Firewall)".
- TrueNAS em VM com disco(s) dedicados (zona Trusted). Datasets: mantida a estrutura antiga da v1 (`media`, `backups`, `jellyfin_config`, `ISO`, `projects`, `shares`) em vez de criar `apps`/`cloud`/`media`/`backups` do zero - decidido 29/07/2026 ao importar o pool `tank_test`. Detalhe em `docs/CHECKLIST.md` §Fase 1.
- Apps em VMs/LXCs (ou, mais tarde, workloads k3s) com dados persistidos no TrueNAS.
- **Prática (decidida 29/07/2026, revista 31/07/2026): todo o servidor/VM do homelab tem IP estático configurado localmente** (`/etc/network/interfaces`), mais reserva DHCP no router como consistência/documentação. Revisto depois de dois LXCs perderem o IPv4 com o lease a expirar sem renovar sozinho - ver detalhe do incidente em `docs/CHECKLIST.md` §Fase 1. Ver `docs/SECRETS.md` §VMs e Containers para a lista.
- Administracao remota via WireGuard; evitar expor interfaces de admin na internet.

## Ordem de construção

**Decidido em 29/07/2026.** A arquitetura alvo (acima) inclui VLANs e uma firewall dedicada desde o início, mas a **ordem de construção** não segue essa mesma ordem: os serviços base (TrueNAS, WireGuard, Caddy, Nextcloud, Jellyfin) são construídos primeiro, numa rede simples sem VLANs (a mesma rede de casa) - só depois é que entra a segmentação de rede (VLANs + firewall dedicada), com os serviços já existentes a serem migrados para as zonas certas.

**Motivo**: construir a VM de firewall dedicada + VLANs (a parte mais nova e menos familiar do projeto) antes de existir qualquer serviço real a funcionar significava arriscar ficar bloqueado logo no início, sem nada a mostrar, e sem ainda haver dados/serviços reais para essa segmentação proteger. Além disso, o RAM continua em 16GB (upgrade para 32GB ainda por fazer, confirmado 29/07/2026) - os serviços base cabem confortavelmente em 16GB; é a firewall dedicada + VLANs + k3s que exigem a folga extra do upgrade. Fazer os serviços primeiro permite progresso real já com o hardware atual.

Isto não muda nenhuma decisão de arquitetura ou tecnologia (continua OpenTofu, continua k3s, continua o desenho de VLANs descrito abaixo) - muda só a ordem pela qual as fases do `docs/CHECKLIST.md` são executadas (Fase 1 = Serviços base, Fase 2 = Rede e Segmentação; antes de 29/07/2026 era o inverso).

## Rede e Segmentação (VLANs + Firewall)

**Decidido em 22/07/2026.** Substitui a exclusão anterior no Escopo ("não inclui arquitetura detalhada de rede"). Desenho completo (diagrama, tabela de VLANs, atribuição de NICs, regras entre zonas) tem documento próprio, mais fácil de consultar: **[`docs/NETWORK.md`](NETWORK.md)**.

Resumo: 3 VLANs (10/DMZ, 20/Trusted, 30/Management) + subnet virtual do túnel WireGuard, mediadas por uma **VM de firewall dedicada** (OPNsense/pfSense, não a firewall nativa do Proxmox - escolhida por ser mais capaz, ex. IDS/IPS; riscos concretos desta escolha em "Riscos e mitigações": RAM, lockout, fiabilidade do USB, manutenção). NIC onboard = trunk para o switch; adaptador USB→RJ45 = perna WAN. Pendente: qual app vai efetivamente para a zona DMZ - ver "Pendências". Nextcloud e Jellyfin já decididos como Trusted-only.

## Router de casa e rede doméstica (fora da segmentação do homelab, novo 28/07/2026)

- **Modelo**: Vodafone Smart Router - Huawei OptiXstar HG8247B7-8N (ONT + router GPON fornecido/bloqueado pela Vodafone).
- **Rede de convidados (guest)**: suportada nativamente na própria interface do router - pode ser ativada diretamente ali, sem depender do OptiPlex nem das VLANs do homelab. Resolve a preocupação de dispositivos convidados ficarem sem rede se o OptiPlex for reiniciado/desligado.
- **VLANs 802.1Q personalizadas** (ex. para isolar IoT): não confirmado se a interface do router expõe essa opção - a confirmar diretamente no admin do router. Equipamentos "Smart Router" da Vodafone tendem a vir com funcionalidades avançadas desativadas por bloqueio do operador.
- **Bridge mode: confirmado desativado pela Vodafone** neste equipamento ([forum Vodafone](https://forum.vodafone.pt/t5/Router/Router-HG8247B7-8N-porta-4-de-2-5Gbps-s%C3%B3-d%C3%A1-100Mbps/m-p/448886)) - reforça a decisão já tomada de o router se manter como gateway real da internet, sem a VM de firewall o substituir (essa alternativa exigiria bridge mode; não disponível sem contacto com o suporte Vodafone, 16913, sem garantia de desbloqueio).
- **Decisão de âmbito**: segmentação adicional de Wi-Fi/guest/IoT da rede doméstica geral mantém-se **independente do OptiPlex** e fora do âmbito das VLANs do homelab (DMZ/Trusted/Management) - evita que dispositivos do dia-a-dia (telemóveis, portáteis, convidados, IoT) dependam da disponibilidade do OptiPlex. Se um dia for preciso mais segmentação do que o router permite nativamente, a via é um access point/switch adicional capaz de VLANs, a jusante do router - não integrado na VM de firewall do homelab.

## Ambiente de desenvolvimento e testes de agentes/LLMs (novo, 28/07/2026)
- Objetivo: VM Linux dedicada para programar e testar agentes/LLMs.
- Modelos: mistura de modelos locais (pequenos/quantizados, ex. via Ollama) e chamadas a APIs externas (Claude, OpenAI, etc.) - confirmado 28/07/2026 que sera "provavelmente as duas coisas".
- **Restricao de hardware**: o OptiPlex (i5-8500T) so tem grafica integrada, sem GPU dedicada - inferencia local fica limitada a modelos pequenos e mais lenta (CPU-only), especialmente notorio em loops de agente (varias chamadas seguidas ao modelo). Testes mais pesados ou mais frequentes devem preferir APIs externas.
- **Zona de rede**: ainda nao decidida (28/07/2026) - Trusted (junto com TrueNAS/Nextcloud/etc., mais simples) vs. zona isolada propria (mais segura, dado que um agente com execucao de codigo/acesso a rede e um perfil de risco diferente de um Jellyfin/Nextcloud - contem melhor um agente com comportamento inesperado, ex. por prompt injection). Ver Pendencias.
- **Impacto em RAM**: mais um consumidor a somar ao orcamento ja apertado (ver Riscos e mitigacoes). Confirmar o teto real de RAM suportado pelo OptiPlex 3060 Micro antes de assumir que 32GB chega, dado este novo requisito.

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
- Exemplos e links em `docs/HARDWARE.md`.

## Orcamento e compras por fases

Nota: esta seccao e sobre **compras**, e a numeracao abaixo e independente da numeracao das fases do `docs/CHECKLIST.md` (que organiza trabalho, nao despesa). O firewall/VLANs, por exemplo, nao custou nada em hardware novo - usou o switch e o adaptador USB que ja existiam.

- Compra 1 (feita, 19/02/2026): apenas o host (229 EUR); HDD/SSD existentes reutilizados; SSD externo ja existente usado como backup.
- Compra 2 (pendente, sem data): 32GB de RAM - ja e o pre-requisito mais urgente, ver "Riscos e mitigacoes".
- Compra 3 (pendente): 2x HDD NAS iguais (4TB ou 6TB) para o ZFS mirror; manter backups a par do RAID.
- Compra 4 (eventual): SSD maior (512GB/1TB) para o host, quando o storage local apertar.

## Plano de instalacao (resumo)
Sequencia completa e atualizada (por fase, com estado feito/pendente): `docs/CHECKLIST.md`. Nota: uma versao anterior deste resumo (7 passos, sem firewall/VLANs/k3s) ficou desatualizada face as decisoes de 22-29/07/2026 e foi substituida por este pointer para evitar as duas versoes divergirem outra vez.

## Riscos e mitigacoes
- Exposicao externa insegura: usar reverse proxy + TLS + limitar portas + admin via VPN.
- Perda de dados (sem RAID): backups frequentes + teste de restores; migrar para RAID quando possivel.
- Crescimento limitado: escolher host com baias/SATA; planear fases.
- RAM insuficiente: **deixou de ser teorico** (confirmado 02/08/2026) - a soma do que esta *configurado* entre todas as VMs/LXCs (~19GB, ja com a firewall de 3GB) excede os 16GB fisicos. So nao rebenta porque o uso *real* ainda fica abaixo disso, mas nao ha folga para o k3s nem para Prometheus/Grafana, e a VM de desenvolvimento vai crescer com Docker/microservicos. Mitigacao: tratar o upgrade de RAM como pre-requisito real da Fase 4 (nao "quando necessario"); confirmar se 32GB chega ou se o OptiPlex 3060 Micro suporta mais.
- Lockout de gestao: se a firewall VM fizer DHCP/DNS/rota para as VLANs internas, uma falha nela pode cortar o acesso a tudo, incluindo ao proprio Proxmox. Mitigacao: manter a gestao do Proxmox acessivel pela zona WAN-side, independente do estado da firewall VM; mudancas de rede sempre com consola local/noVNC disponivel, nunca so remotamente. **Validado na pratica (06/08/2026)**: durante a migracao para as VLANs, a VPN ficou inacessivel e o acesso ao Proxmox pela zona Management tambem - o IP antigo na rede plana (`192.168.1.206`) foi o unico caminho que se manteve sempre a funcionar, e foi por ele que o diagnostico inteiro foi feito (incluindo chegar a GUI do OPNsense por tunel SSH). Reforca a decisao: **nao remover o IP da rede plana do Proxmox** enquanto a firewall for o unico caminho para a Management.
- Fiabilidade do adaptador USB-RJ45: e hardware de consumo, nao de servidor (pode ter resets sob carga sustentada). Mitigacao: atribuido ao papel WAN (mais simples/menos critico), nao ao trunk das VLANs internas.
- Perda de configuracao da firewall: mais critico que perder "um servico" - e toda a politica de rede/seguranca. Mitigacao: exportar a configuracao da propria firewall (ex. config.xml do OPNsense) alem do backup normal da VM.

## Pendencias
Checklist completo com estado (feito/pendente) de todas as tarefas: `docs/CHECKLIST.md`. Decisoes ainda em aberto (nao tarefas): qual app vai para a zona DMZ (exposta publicamente via Caddy) - Nextcloud e Jellyfin ja decididos como Trusted-only, por isso o objetivo original "expor 1-2 apps" fica sem app associada ate isto ficar decidido; zona de rede para a nova VM de desenvolvimento/agentes-LLMs (Trusted vs. zona isolada propria); confirmar o teto real de RAM do OptiPlex 3060 Micro (assumido 32GB); se o Healthchecks.io corre dentro ou fora do k3s; recriar ou nao a stack RAG da v1; destino/desligamento do PC antigo (v1) apos o v2 estar operacional.

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
- 18/07/2026: decidido plano de ferramentas/boas praticas para o v2 (ver `docs/TOOLING.md`): Obsidian (vault = este repo, sync via Git, sem Obsidian Sync pago) para documentacao; Uptime Kuma + Healthchecks.io self-hosted com alertas Slack para monitorizacao; adocao de IaC (OpenTofu + Ansible) desde ja.
- 22/07/2026: plano de ferramentas revisto para dar prioridade as praticas mais representativas de infraestrutura moderna. Tres mudancas: (1) servicos de aplicacao passam a correr num cluster k3s (Kubernetes) em vez de LXC/VM por servico, entrando cedo enquanto o custo de refazer ainda e baixo; (2) Prometheus+Grafana deixam de ser "mais tarde" e entram na fase inicial, porque "esta no ar?" nao responde a "porque esta lento" nem deteta degradacao gradual; (3) workflow de GitHub Actions a validar o IaC (tofu fmt/validate, ansible-lint, helm lint) antes de qualquer apply real, dado que um apply mal formado nao falha um teste, destroi uma VM. Mantido OpenTofu (nao Terraform) - ver justificacao na seccao 4 do plano.
- 22/07/2026: criado `docs/CHECKLIST.md` como documento operacional unico com o estado (feito/pendente) de todas as tarefas do projeto, consolidando o que estava espalhado em "Proximos Passos" (README.md), "Pendencias" (este ficheiro) e a "Sequencia de execucao recomendada" do plano de ferramentas. Este ficheiro (PROJECT_CONTEXT.md) mantem-se como o log de decisoes/contexto; o CHECKLIST.md e so o estado das tarefas.
- 22/07/2026: revisao de hardware. Confirmado que o HDD 1TB (bay USB TooQ) esta visivel mas com o pool ZFS da NAS antiga (v1) por importar - nao e um problema de hardware, falta criar a VM TrueNAS + passthrough + "Import pool". Confirmado tambem hardware de rede adicional (adaptador USB->RJ45 TP-Link + switch TL-SG608E) - topologia final ainda nao decidida, ver nova seccao "Rede" acima.
- 22/07/2026: correcao - o TL-SG608E tinha sido registado incorretamente como "unmanaged, sem VLANs". Confirmado via datasheet oficial TP-Link (pesquisa web) que e um Easy Smart Switch gerido, com suporte a VLAN 802.1Q (port-based, tag-based, MTU VLAN), QoS, IGMP Snooping e LACP. Foi escolhido precisamente por isto. Seccao "Rede" corrigida.
- 22/07/2026: decidida a arquitetura de rede completa (substitui a exclusao anterior no Escopo). VLANs: 10/DMZ (WireGuard), 20/Trusted (TrueNAS, Caddy, Nextcloud, Jellyfin, k3s), 30/Management (Proxmox, switch); subnet do tunel WireGuard (10.10.40.0/24) e virtual, nao e VLAN do switch. NIC onboard = trunk para o switch; adaptador USB->RJ45 = perna WAN. Decidida VM de firewall dedicada (OPNsense/pfSense), nao a firewall nativa do Proxmox - riscos (RAM, lockout, fiabilidade do USB, backup da config) registados em "Riscos e mitigacoes". Nextcloud e Jellyfin decididos como Trusted-only (so acesso via WireGuard, sem exposicao publica) - fica pendente decidir qual app vai para a zona DMZ. Seccao "Rede (hardware confirmado, topologia por decidir)" substituida por "Rede e Segmentacao (VLANs + Firewall)". Checklist atualizado com nova Fase 1 dedicada e fases seguintes renumeradas.
- 28/07/2026: novo requisito - VM Linux para programar e testar agentes/LLMs, com mistura de modelos locais e APIs externas. Hardware sem GPU dedicada (so grafica integrada) limita inferencia local a modelos pequenos/lentos. Zona de rede (Trusted vs. isolada) fica pendente. Reforca o risco de RAM ja registado - ver nova seccao "Ambiente de desenvolvimento e testes de agentes/LLMs".
- 28/07/2026: identificado o router de casa - Vodafone Smart Router (Huawei OptiXstar HG8247B7-8N). Confirmado via pesquisa web: guest network suportado nativamente (independente do OptiPlex); bridge mode desativado pela Vodafone (reforca a decisao de nao substituir o router pela VM de firewall como gateway); VLANs 802.1Q personalizadas nao confirmadas na interface do router. Decidido manter segmentacao Wi-Fi/guest/IoT fora do ambito das VLANs do homelab e independente do OptiPlex - ver nova seccao "Router de casa e rede domestica".
- 29/07/2026: criado `docs/NETWORK.md` como documento de referencia proprio para a arquitetura de rede (diagrama, tabela de VLANs, atribuicao de NICs, regras entre zonas), mais facil de consultar do que percorrer o log de decisoes. A seccao "Rede e Segmentacao" deste ficheiro ficou resumida a um pointer.
- 29/07/2026: auditoria completa de toda a documentacao. Corrigido: "Plano de instalacao (resumo)" (7 passos antigos, sem firewall/VLANs/k3s) substituido por pointer para o CHECKLIST.md; README.md corrigido (Caddy descrito como exposto publicamente, port-forward direto ao reverse proxy - ambos desatualizados); WORKFLOW.md com Caddy em falta na tabela/diagrama; TOOLING.md sem mencionar CHECKLIST.md/NETWORK.md na estrutura recomendada; adicionadas duas pendencias novas (teto de RAM, localizacao do Healthchecks.io) para consistencia entre este ficheiro e o CHECKLIST.md. Corrigido tambem o uso do travessao longo (em-dash) em todos os documentos por hifen simples (instrucao global do utilizador pede isso) - 114 ocorrencias substituidas.
- 29/07/2026: **decidida a ordem de construcao** (nova seccao "Ordem de construcao") - Fase 1 do CHECKLIST.md passa a ser Servicos base (TrueNAS, WireGuard, Caddy, Nextcloud, Jellyfin, numa rede simples sem VLANs), com a Fase 2 (Rede e Segmentacao - VLANs + firewall dedicada) a vir depois, migrando os servicos ja existentes para as zonas certas. Era o inverso desde 22/07/2026. Motivo: evitar bloquear o primeiro progresso real do projeto na parte mais nova/complexa (firewall dedicada + VLANs) antes de existir qualquer servico a funcionar; confirmado que o RAM continua em 16GB (upgrade ainda por fazer), e os servicos base cabem nisso sem precisar da folga extra que a firewall dedicada + k3s exigem.
- 29/07/2026: **inicio real da implementacao**. VM TrueNAS (102) criada no Proxmox (6GB RAM, 4 cores, disco de 32GB para o SO), disco de 1TB anexado por passthrough via `by-id` (nao um disco virtual novo). TrueNAS SCALE 25.10.5 instalado no disco de 32GB; pool ZFS `tank_test` da v1 importada com sucesso, 0 erros, scrub anterior saudavel. Decidido manter a estrutura de datasets antiga (`media`, `backups`, `jellyfin_config`, `ISO`, `projects`, `shares`) em vez de criar `apps`/`cloud`/`media`/`backups` do zero - ver "Arquitetura (alto nivel)". Identificado um zvol `VM_ubuntu_wireguard-ulqfm6`: disco de uma VM que corria dentro do proprio TrueNAS na v1 (TrueNAS SCALE tem hypervisor embutido) - nao faz parte da arquitetura v2 (Proxmox e o unico hypervisor), fica so como arquivo ate confirmar o WireGuard novo e poder ser apagado. Criado `docs/SECRETS.md` (ver commit anterior) ja com os acessos reais do Proxmox e do TrueNAS.
- 29/07/2026: confirmado que o PC antigo (v1) esta desligado (resolveu duvida sobre o IP 192.168.1.184, que era dele). Criadas partilhas SMB (`shares`, `media`, `backups`) e export NFS (`media`) no TrueNAS, com utilizador dedicado `rui` (so SMB Access). **Decidida a pratica de reserva DHCP no router para todo o servidor/VM** (em vez de DHCP dinamico) - primeira aplicada ao TrueNAS (192.168.1.66, MAC confirmado no router).
- 31/07/2026: **Fase 1 concluida** - Caddy (LXC 101), Nextcloud (LXC 104) e Jellyfin (LXC 105) criados e validados. Nextcloud e Jellyfin correm Docker Compose dentro de LXCs unprivileged (`nesting=1,keyctl=1`), com os dados no TrueNAS via NFS montado no Proxmox host e passado aos containers por bind mount - um LXC unprivileged nao consegue montar NFS diretamente. **Licao tecnica**: exports NFS usados por estes containers precisam de `Mapall` (nao `Maproot`), porque o "root" de dentro de um LXC unprivileged com Docker por cima nunca chega ao TrueNAS como UID 0 verdadeiro.
- 31/07/2026: **revista a pratica de enderecamento** - reserva DHCP no router deixa de ser suficiente por si so. Depois de dois LXCs perderem o IPv4 com o lease a expirar sem renovar sozinho, os 4 LXCs passaram a **IP estatico** configurado localmente, com a reserva no router a ficar so como documentacao. Detalhe do incidente em `docs/CHECKLIST.md` §Fase 1.
- 02/08/2026: **backup automatizado e validado de ponta a ponta** - SSD externo de 1TB formatado em exFAT (decisao: mantem-se utilizavel como disco Windows comum, em troca de perder as Replication Tasks nativas do TrueNAS), com `rsync` diario via cron a copiar os datasets `nextcloud` e `shares`. Restore testado em 3 niveis (listagens, checksum, reproducao real de um ficheiro). Confirmada tambem a VM 100 `mnt-mate` (Linux Mint, 4 cores/8GB/64GB), que estava por identificar ha semanas: e o ambiente de desenvolvimento/testes (VS Code + Docker, microservicos).
- 06/08/2026: **inicio da Fase 2 - a rede segmentada passou a existir de facto**. Porta trunk configurada no switch, bridge VLAN-aware no Proxmox, adaptador USB→RJ45 como perna WAN, e a VM de firewall dedicada criada (OPNsense, VM 106) com uma interface por zona (WAN `192.168.1.95`, DMZ `10.10.10.1`, Trusted `10.10.20.1`, Management `10.10.30.1`). WireGuard migrado para a DMZ (`10.10.10.10`) e o Proxmox host ganhou uma segunda interface na Management (`10.10.30.2`), mantendo a da rede plana. **Descoberta importante sobre o desenho**: a porta trunk do switch transporta tambem a VLAN 1 sem tag, ou seja, o switch e ao mesmo tempo trunk do homelab e switch normal da rede domestica - a rede de casa **nao** passa pela firewall dedicada, so as VLANs 10/20/30 e que passam. Isto nao estava explicito no esquema original e so foi detetado ao montar fisicamente a Fase 2 (ver `docs/NETWORK.md`).
- 06/08/2026: **incidente que validou o risco de "lockout de gestao"** ja registado em Riscos - depois da migracao, a VPN ficou completamente inacessivel e o acesso ao Proxmox pela Management tambem. Causa real: a regra de port-forward no router continuava a apontar para o IP antigo do WireGuard, de antes da migracao. O diagnostico so foi possivel porque o Proxmox manteve o IP antigo na rede plana - reforcado em Riscos que esse IP nao deve ser removido enquanto a firewall for o unico caminho para a Management. Detalhe completo em `docs/CHECKLIST.md` §Fase 2.
