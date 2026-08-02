# Checklist de implementação (Homelab v2)

Documento operacional único com o estado de todas as tarefas do projeto. Os "porquês" e decisões ficam nos documentos de decisão (`PROJECT_CONTEXT.md`, `PLANO_FERRAMENTAS_E_BOAS_PRATICAS.md`) - aqui só o estado (feito/pendente) e um link de volta para o contexto.

Convenção: marcar `[x]` só quando verificado a funcionar (não quando "aplicado sem erro") - ver skill `verify`.

## Fase 0 - Hardware

- [x] Escolher e comprar o host (Dell OptiPlex 3060 Micro, i5-8500T/16GB/SSD 256GB) - ver [HARDWARE_SHORTLIST.md](HARDWARE_SHORTLIST.md#escolha-atual-host-inicial)
- [x] Instalar Proxmox VE no host
- [ ] Confirmar especificações reais ao receber (SSD NVMe vs SATA, RAM 1x16GB vs 2x8GB) - ver [HARDWARE_SHORTLIST.md](HARDWARE_SHORTLIST.md#escolha-atual-host-inicial)
- [ ] **Upgrade para 32GB RAM** - confirmado (29/07/2026) que ainda temos só os 16GB atuais. Não bloqueia a Fase 1 (serviços base cabem em 16GB), mas é pré-requisito antes de somar VLANs/firewall dedicada/k3s (ver [PROJECT_CONTEXT.md §Riscos](PROJECT_CONTEXT.md#riscos-e-mitigacoes)).
- [ ] Upgrade SSD para 512GB/1TB (quando o storage apertar)

## Fase 1 - Serviços base (rede simples, sem VLANs ainda)

**Ordem de construção decidida em 29/07/2026** (ver [PROJECT_CONTEXT.md §Ordem de construção](PROJECT_CONTEXT.md#ordem-de-construcao)): estes serviços entram primeiro, numa rede simples (a mesma rede de casa, sem VLANs), para validar Proxmox + storage e ganhar confiança com algo real a funcionar antes de somar a complexidade de VLANs + firewall dedicada. Migram para as zonas certas (Trusted/DMZ) na Fase 2.

Regista os acessos (URLs, utilizadores, passwords, caminhos) em `docs/SEGREDOS.md` à medida que cada serviço for criado - não esperar até ao fim.

- [x] Provisionar VM TrueNAS no Proxmox (VM 102) e passar o HDD 1TB (passthrough de disco via `by-id`, ver `SEGREDOS.md`) - ver [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md#plano-de-instalacao-resumo)
- [x] No TrueNAS SCALE, importar o pool ZFS existente da NAS antiga (v1) - pool `tank_test`, 0 erros, scrub anterior saudável
- [x] **Decidido (29/07/2026): manter a estrutura de datasets antiga da v1** em vez de criar `apps`/`cloud`/`media`/`backups` do zero - datasets encontrados: `media`, `backups`, `jellyfin_config`, `ISO`, `projects`, `shares` (149GB, conteúdo por identificar), e o zvol `VM_ubuntu_wireguard-ulqfm6` (disco de uma VM WireGuard antiga, corria dentro do próprio TrueNAS - não faz parte da arquitetura nova, é só arquivo; pode apagar-se depois de confirmado o WireGuard novo)
- [x] Configurar partilhas SMB para `shares`, `media` e `backups` (utilizador dedicado `rui`, criado com SMB Access apenas - ver `SEGREDOS.md`), e export NFS para `media` (para o Jellyfin, mais tarde)
- [x] Decidido/criado dataset `nextcloud` (novo, dedicado) - não reaproveitado `shares`/`projects`, para não misturar a gestão própria do Nextcloud (permissões, snapshots, quota) com ficheiros geridos manualmente
- [x] Instalar WireGuard (LXC 103, privilegiado, Debian 12) - servidor a correr, túnel `10.10.40.0/24`, porta `51820`
  - [x] Reserva DHCP no router para o LXC (MAC `bc:24:11:52:25:67` → 192.168.1.78)
  - [x] Decidido reaproveitar o DDNS da v1 - No-IP, `HOSTNAME.ddns.net` (ver `SEGREDOS.md`)
  - [x] Port-forward UDP 51820 no router para 192.168.1.78 (regra "Wireguard" reaproveitada da v1, IP atualizado)
  - [x] Adicionado o primeiro peer ("phone", 10.10.40.2) e testada ligação de fora de casa - **funcionou**
- [x] Instalar Caddy (LXC 101, Debian 12) - serviço a correr com configuração por omissão (por agora só HTTPS interno via VPN - sem exposição pública até haver uma app decidida, ver Pendências); Caddyfile real (`reverse_proxy`) fica para quando o Nextcloud/Jellyfin existirem
  - [x] Reserva DHCP no router para o LXC (MAC `bc:24:11:de:f8:97` → 192.168.1.83)
- [x] Instalar Nextcloud (LXC 104, Debian 12, unprivileged+nesting, Docker Compose: nextcloud+mariadb+redis) - **não exposto publicamente** (sem port-forward, decidido 22/07/2026), storage de ficheiros a apontar para o dataset `nextcloud` no TrueNAS via NFS; acesso direto por IP:porta por agora, fica atrás do Caddy quando o Caddyfile for configurado
  - [x] Reserva DHCP no router para o LXC (MAC `bc:24:11:1f:2a:bf` → 192.168.1.84)
- [x] Instalar/recriar Jellyfin (LXC 105, Debian 12, unprivileged+nesting, Docker Compose) - mesmo padrão da v1: só via WireGuard (sem port-forward), storage de media a apontar para o dataset `media` no TrueNAS via NFS
  - [x] Reserva DHCP no router para o LXC (MAC `bc:24:11:2b:94:48` → 192.168.1.87)
- [x] Automatizar backups para o SSD externo 1TB (script `rsync` + cron no Proxmox host, exFAT em vez de pool ZFS - ver Histórico) - datasets `nextcloud` e `shares`
  - [ ] Testar um restore completo

## Fase 2 - Rede e Segmentação (VLANs + Firewall)

Diagrama, tabela de VLANs, atribuição de NICs e regras entre zonas: [ESQUEMA_LOGICO_REDE.md](ESQUEMA_LOGICO_REDE.md). Decisão e riscos: [PROJECT_CONTEXT.md §Rede e Segmentação](PROJECT_CONTEXT.md#rede-e-segmentacao-vlans--firewall). Passa a acontecer depois da Fase 1 (era antes, até 29/07/2026) - ver "Ordem de construção".

- [ ] Configurar porta trunk no switch TL-SG608E (VLANs 10/20/30 com tag) ligada à NIC onboard do OptiPlex
- [ ] Configurar a NIC onboard do Proxmox como bridge VLAN-aware (trunk DMZ/Trusted/Management)
- [ ] Configurar o adaptador USB→RJ45 como bridge separada, sem tags (perna WAN, ligada à rede de casa/router)
- [ ] Criar a VM de firewall dedicada (OPNsense ou pfSense), com uma interface por zona (WAN, DMZ, Trusted, Management)
- [ ] Configurar regras do firewall: DMZ→Trusted só nas portas necessárias; DMZ→Management bloqueado; WAN-side→Management só a partir do IP do PC do Rui; túnel WireGuard→Trusted+Management permitido
- [ ] Migrar os serviços da Fase 1 para as zonas certas: TrueNAS, Caddy, Nextcloud, Jellyfin → Trusted; WireGuard → DMZ
- [ ] Atualizar o port-forward do router: passa a apontar para a perna WAN-side da VM de firewall (não diretamente para o Caddy)
- [ ] Exportar e guardar a configuração da firewall (ex.: `config.xml` do OPNsense) como parte do backup - perder isto é perder toda a política de rede, não só "um serviço"

## Fase 3 - Storage / RAID (mais tarde)

- [ ] Comprar 2x HDD NAS iguais (4TB ou 6TB)
- [ ] Migrar para ZFS mirror (RAID1) no TrueNAS

## Fase 4 - IaC e Kubernetes

Ver [PLANO_FERRAMENTAS_E_BOAS_PRATICAS.md §4-5](PLANO_FERRAMENTAS_E_BOAS_PRATICAS.md#4-infrastructure-as-code) para a justificação de cada escolha.

- [ ] Scaffold do repo: `infra/opentofu`, `infra/ansible`, `infra/kubernetes`
- [ ] Criar utilizador/role dedicado + API token no Proxmox para o OpenTofu (nunca `root@pam`)
- [ ] Workflow de GitHub Actions a validar `infra/` (`tofu fmt`/`validate`, `ansible-lint`, `helm lint`) - antes do primeiro `apply` real
- [ ] Provisionar a VM TrueNAS via OpenTofu (substituir o passo manual da Fase 1)
- [ ] Provisionar 1 VM via OpenTofu + instalar k3s nela via Ansible (cluster de nó único, zona Trusted)
- [ ] Configurar `.gitignore` para segredos (`*.tfvars`, `secrets/`, `*vault.yml`, `*values-secret.yaml`) + ficheiros `.example`
- [ ] Migrar Jellyfin/Nextcloud para manifests/Helm no k3s, com storage a apontar para o TrueNAS

## Fase 5 - Monitorização e alertas (Slack)

Ver [PLANO_FERRAMENTAS_E_BOAS_PRATICAS.md §3](PLANO_FERRAMENTAS_E_BOAS_PRATICAS.md#3-monitorizacao-e-alertas--slack).

- [ ] Criar canal `#homelab-alerts` no Slack + Incoming Webhook
- [ ] Instalar Uptime Kuma (como workload no k3s) e ligar ao webhook
- [ ] Instalar `kube-prometheus-stack` (Prometheus + Grafana) no k3s
- [ ] Instalar Healthchecks.io self-hosted para os jobs agendados (backups, scrub ZFS, runs do Ansible)
- [ ] (Opcional) Tarefa agendada (skill `schedule`) com resumo diário em linguagem natural no Slack

## Fase 6 - Documentação (Obsidian)

Ver [PLANO_FERRAMENTAS_E_BOAS_PRATICAS.md §2](PLANO_FERRAMENTAS_E_BOAS_PRATICAS.md#2-documentação--obsidian).

- [ ] Abrir o repo como vault no Obsidian
- [ ] Instalar o plugin `obsidian-git` e confirmar sync entre dispositivos
- [ ] Criar `docs/services/` com uma nota por serviço à medida que cada um for instalado
- [ ] Criar `docs/runbooks/` com o primeiro procedimento de recuperação (ex.: TrueNAS)
- [ ] Aplicar tags (`#pendente`, `#decisão`, `#risco`, `#servico`) nas notas existentes

## Decisões em aberto (não são tarefas - precisam de decisão antes de virar tarefa)

- [ ] **Qual app vai para a zona DMZ** (exposta publicamente via Caddy) - com Nextcloud e Jellyfin decididos como Trusted-only, o objetivo original "expor 1-2 apps na internet" fica sem app associada até isto ficar decidido
- [ ] **Zona de rede para a VM de desenvolvimento/agentes-LLMs** (novo, 28/07/2026) - Trusted (mais simples) vs. zona isolada própria (contém melhor um agente com comportamento inesperado) - ver [PROJECT_CONTEXT.md §Ambiente de desenvolvimento](PROJECT_CONTEXT.md#ambiente-de-desenvolvimento-e-testes-de-agentesllms-novo-28072026)
- [ ] Confirmar o teto real de RAM do OptiPlex 3060 Micro (assumido 32GB até agora) - o novo requisito de agentes/LLMs pode justificar mais
- [ ] Se o Healthchecks.io corre como workload no k3s (como o Uptime Kuma) ou fica à parte - ainda não especificado em nenhum documento
- [ ] Decidir se/quando recriar a stack RAG (Open WebUI + Ollama + Qdrant) da v1
- [ ] Confirmar destino do PC antigo (v1) após o v2 estar operacional - confirmado (29/07/2026) que está atualmente desligado; falta só decidir o destino final (guardar, reaproveitar, vender)

## Histórico

- 22/07/2026: criado este documento, consolidando "Próximos Passos" (README.md), "Pendências" (PROJECT_CONTEXT.md) e "Sequência de execução recomendada" (PLANO_FERRAMENTAS_E_BOAS_PRATICAS.md §5) num único checklist com estado.
- 22/07/2026: revisão de hardware - corrigido o passo do HDD (bay TooQ) para deixar claro que é preciso importar o pool ZFS existente, não formatar; adicionada decisão em aberto sobre a topologia de rede do adaptador USB->RJ45 + switch TL-SG608E.
- 22/07/2026: correção - o TL-SG608E tinha sido descrito como "unmanaged, sem VLANs"; confirmado (datasheet oficial TP-Link) que é um Easy Smart Switch gerido com suporte a VLAN 802.1Q. Corrigido em [PROJECT_CONTEXT.md §Rede e Segmentação](PROJECT_CONTEXT.md#rede-e-segmentacao-vlans--firewall).
- 22/07/2026: consolidada a arquitetura de rede completa - nova Fase 1 "Rede e Segmentação" (VLANs 10/DMZ, 20/Trusted, 30/Management + VM de firewall dedicada), Nextcloud e Jellyfin decididos como Trusted-only (só via WireGuard), e nova decisão em aberto sobre qual app expor via DMZ. Fases seguintes renumeradas (+1).
- 28/07/2026: novo requisito - VM Linux para programar e testar agentes/LLMs (modelos locais + APIs externas). Adicionadas duas decisões em aberto: zona de rede desta VM, e confirmar o teto real de RAM do OptiPlex (o pressuposto de 32GB pode não chegar).
- 29/07/2026: criado `docs/ESQUEMA_LOGICO_REDE.md`; link da Fase 1 atualizado para apontar para lá em vez de só para o PROJECT_CONTEXT.md.
- 29/07/2026: auditoria da documentação. Adicionada decisão em aberto sobre onde corre o Healthchecks.io (dentro ou fora do k3s). Corrigido o uso do travessão longo por hífen simples em todo o documento.
- 29/07/2026: **reordenadas as Fases 1 e 2** - Serviços base passa a vir antes de Rede e Segmentação (era o inverso). Motivo: construir a VM de firewall dedicada + VLANs antes de ter qualquer serviço real a funcionar bloqueava o primeiro progresso visível na parte mais nova e menos familiar do projeto, sem nada ainda para proteger. Confirmado que o RAM continua em 16GB (upgrade ainda não feito) - reforça esta ordem, já que a Fase 1 cabe em 16GB e a Fase 2 (com firewall dedicada) é que precisa da folga extra. Fase 1 (serviços) reescrita para não presumir zonas de rede que ainda não existem; Fase 2 ganhou uma tarefa nova de migração dos serviços para as zonas certas.
- 29/07/2026: **início real da implementação** - VM TrueNAS (102) criada no Proxmox, disco de 1TB anexado por passthrough `by-id`, TrueNAS SCALE 25.10.5 instalado (disco de 32GB, sem tocar no de 1TB), pool ZFS `tank_test` importada com sucesso (0 erros). Decidido manter a estrutura de datasets antiga da v1 em vez de criar `apps`/`cloud`/`media`/`backups` do zero - ver detalhe na Fase 1 acima. Identificado um zvol `VM_ubuntu_wireguard-ulqfm6`, resto de uma VM que corria dentro do próprio TrueNAS na v1 (o TrueNAS SCALE tem hypervisor embutido) - não faz parte da arquitetura v2 (Proxmox é o único hypervisor), fica só como arquivo.
- 29/07/2026: criado utilizador local `rui` no TrueNAS (só com SMB Access, sem acesso à shell/TrueNAS/SSH). Criadas partilhas SMB para `shares`, `media` e `backups`, com o `rui` a ganhar acesso total (ACL ou dono, consoante o dataset usa NFSv4 ACL ou permissões Unix simples) e aplicado recursivamente aos ficheiros já existentes. Criado export NFS para `media`, para o Jellyfin usar mais tarde.
- 29/07/2026: criado dataset `nextcloud` (novo, dedicado) no TrueNAS - decidido não reaproveitar `shares`/`projects`, para o Nextcloud ter permissões/snapshots/quota próprios sem misturar com ficheiros geridos manualmente.
- 29/07/2026: criado LXC WireGuard (103, privilegiado, Debian 12, 1 core/512MB/4GB disco, `vmbr0`). Corrigido um problema de rede - o `/etc/network/interfaces` não tinha entrada para `eth0` (só `lo`), por isso a interface nunca arrancava sozinha; adicionada `auto eth0` + `iface eth0 inet dhcp`. Servidor WireGuard instalado e a correr (túnel `10.10.40.0/24`, porta `51820`, chaves geradas). Faltam: reserva DHCP, decisão de DDNS, primeiro peer, port-forward.
- 29/07/2026: **WireGuard completo e validado** - reserva DHCP feita (192.168.1.78), DDNS decidido (reaproveitado o No-IP da v1, `HOSTNAME.ddns.net`), port-forward UDP 51820 configurado no router, primeiro peer ("phone") criado e ligação testada com sucesso a partir de fora de casa. Decidido não guardar o QR code/config do cliente como ficheiro em lado nenhum (contém a chave privada do cliente) - regenera-se sempre a partir do servidor, receita em `SEGREDOS.md`.
- 31/07/2026: criado LXC Caddy (101, Debian 12, 1 core/512MB/4GB disco, `vmbr0`). Reapareceu o mesmo bug de rede do WireGuard (`/etc/network/interfaces` sem entrada para `eth0`) - mesma correção aplicada (`auto eth0` + `iface eth0 inet dhcp`). Caddy instalado e a correr (`systemctl status caddy` ativo, página por omissão na porta 80). Reserva DHCP feita (192.168.1.83). Configuração real do Caddyfile (reverse proxy para Nextcloud/Jellyfin) fica para quando esses serviços existirem.
- 31/07/2026: **Nextcloud completo e validado** - criado LXC 104 (Debian 12, unprivileged, features `nesting=1,keyctl=1` para correr Docker lá dentro). Export NFS criado no TrueNAS para o dataset `nextcloud`. Montagem direta do NFS de dentro do container falhou (`Operation not permitted` - um container unprivileged não pode montar sistemas de ficheiros de rede diretamente, mesmo com nesting); resolvido montando o NFS no próprio Proxmox host e passando para o container como bind mount (`pct set 104 -mp0 ...`). Isso revelou um segundo problema: o Nextcloud falhava a inicializar com `chown "/var/www/html/data" failed: Operation not permitted`, porque o `Maproot` do export NFS só reconhece como root os pedidos que chegam como UID 0 verdadeiro, e o "root" de dentro do container (unprivileged, atrás de mais uma camada de Docker) chega ao TrueNAS com um UID deslocado, não root. Resolvido trocando `Maproot` por `Mapall` (root/wheel) no export NFS, que trata todos os pedidos como root independentemente do UID de origem. **Nota para o Jellyfin (próximo passo)**: é muito provável que o mesmo problema (mount direto falha, chown falha com só Maproot) se repita, já que vai usar o mesmo padrão de LXC unprivileged + NFS - aplicar `Mapall` já a partir do início evita repetir este diagnóstico. Docker Compose (nextcloud:latest + mariadb:10.11 + redis:alpine) instalado e a correr, conta de administrador criada, apps recomendadas instaladas. Reserva DHCP feita (192.168.1.84).
- 31/07/2026: **Jellyfin completo e validado** - criado LXC 105 (Debian 12, unprivileged, `nesting=1,keyctl=1`). Desta vez o `Mapall` (root/wheel) foi aplicado ao export NFS do `media` logo à partida - mount no Proxmox host + bind mount (`mp0`) para o container funcionou à primeira, sem repetir o diagnóstico do Nextcloud (confirma que a lição serviu). Docker Compose só com um container (`jellyfin/jellyfin`), sem base de dados/cache externas (usa SQLite embutido, que é a prática recomendada para o Jellyfin, ao contrário do Nextcloud). Migrados `Movies`, `Series` e `Music` de `shares/media/` (resto da app antiga do TrueNAS) para o dataset dedicado `media`; `Photos` ficou de fora, vai para o Nextcloud com contas pessoais separadas (`rui`, `utilizador2`) em vez de para o `admin`. Bibliotecas configuradas com trickplay e extração de imagens de capítulos desativados (poupança de CPU/disco, LXC só tem 2 cores/2GB RAM). Scan concluído com sucesso, capas e metadados a aparecer corretamente.
  - **Incidente: lease de DHCP expirado (dois episódios)** - depois de várias horas, tanto o Nextcloud (104) como o Jellyfin (105) ficaram inacessíveis (`ping` a dar "No route to host", mesmo a partir do próprio Proxmox host). Diagnóstico: `pct exec <id> -- ip a show eth0` mostrou a interface `UP` mas sem endereço IPv4 (só IPv6) - o lease de DHCP tinha expirado sem renovar. Primeira tentativa de correção: `systemctl restart networking` (Nextcloud) e `pct stop`/`pct start` completo (Jellyfin, que teve um problema extra: o `docker ps` ficou preso, provavelmente por o mount NFS do Proxmox host ter ficado "stale" durante a instabilidade de rede, bloqueando o Docker). Isto **não resolveu de forma permanente** - pouco depois, ambos voltaram a ficar inacessíveis, e o Caddy (101) e o WireGuard (103) mostraram o mesmo lease a poucos minutos de expirar. Causa real: o `dhclient` não fica a correr de forma persistente/fiável neste ambiente para renovar o lease sozinho, independentemente de como a interface é trazida acima. **Correção definitiva**: trocados os 4 LXCs de DHCP para **IP estático** em `/etc/network/interfaces` (mesmo IP de sempre, já reservado no router), eliminando por completo a dependência de renovação de lease. Túnel WireGuard confirmado a sobreviver ao reinício completo do container (`wg show` ok, peer "phone" preservado). A partir de agora, todo o LXC/VM novo deve ser configurado com IP estático desde o início, não DHCP (ver `PROJECT_CONTEXT.md` §Arquitetura).
- 02/08/2026: **Backup automatizado para o SSD externo (1TB, SanDisk Portable SSD)**. Decidido formatar em **exFAT** (não ZFS) para o disco continuar utilizável como disco externo comum no Windows quando necessário - troca a possibilidade de Replication Tasks nativas do TrueNAS por uma cópia `rsync` simples. Montado no Proxmox host (`/mnt/pve/backup-ssd`, `nofail` no fstab para não bloquear o arranque se o disco estiver desligado). Criado export NFS novo para o dataset `shares` (com `Mapall` aplicado desde o início). Script `/usr/local/bin/backup-homelab.sh` copia `nextcloud` e `shares` via NFS (montados no Proxmox host) para o SSD, agendado por cron diário às 4h. **Incidente**: primeira tentativa usou `rsync -a`, que falhou (`chown failed: Operation not permitted`) porque o **exFAT não suporta dono/grupo Unix** - o `-a` tenta sempre preservar isso, e o rsync aborta a transferência inteira quando falha. Corrigido com `rsync -rlt --delete --modify-window=1` (sem tentar preservar dono/grupo/permissões, que o exFAT não sabe guardar de qualquer forma; `--modify-window` compensa a precisão mais baixa das datas no exFAT). Backup completo validado (~400GB, sem erros). Decidido não expor o SSD por SMB (nem no Proxmox host, nem via passthrough para o TrueNAS) - acesso ocasional a partir do Windows é feito movendo fisicamente o disco. **Por fazer**: testar um restore completo a partir desta cópia.
