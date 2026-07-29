# Checklist de implementação (Homelab v2)

Documento operacional único com o estado de todas as tarefas do projeto. Os "porquês" e decisões ficam nos documentos de decisão (`PROJECT_CONTEXT.md`, `PLANO_FERRAMENTAS_E_BOAS_PRATICAS.md`) - aqui só o estado (feito/pendente) e um link de volta para o contexto.

Convenção: marcar `[x]` só quando verificado a funcionar (não quando "aplicado sem erro") - ver skill `verify`.

## Fase 0 - Hardware

- [x] Escolher e comprar o host (Dell OptiPlex 3060 Micro, i5-8500T/16GB/SSD 256GB) - ver [HARDWARE_SHORTLIST.md](HARDWARE_SHORTLIST.md#escolha-atual-host-inicial)
- [x] Instalar Proxmox VE no host
- [ ] Confirmar especificações reais ao receber (SSD NVMe vs SATA, RAM 1x16GB vs 2x8GB) - ver [HARDWARE_SHORTLIST.md](HARDWARE_SHORTLIST.md#escolha-atual-host-inicial)
- [ ] **Upgrade para 32GB RAM** - deixou de ser "quando necessário": com TrueNAS + k3s + Prometheus/Grafana + VM de firewall dedicada, os 16GB atuais ficam sem folga (ver [PROJECT_CONTEXT.md §Riscos](PROJECT_CONTEXT.md#riscos-e-mitigacoes)). Tratar como pré-requisito antes de ligar tudo em simultâneo.
- [ ] Upgrade SSD para 512GB/1TB (quando o storage apertar)

## Fase 1 - Rede e Segmentação (VLANs + Firewall)

Diagrama, tabela de VLANs, atribuição de NICs e regras entre zonas: [ESQUEMA_LOGICO_REDE.md](ESQUEMA_LOGICO_REDE.md). Decisão e riscos: [PROJECT_CONTEXT.md §Rede e Segmentação](PROJECT_CONTEXT.md#rede-e-segmentacao-vlans--firewall).

- [ ] Configurar porta trunk no switch TL-SG608E (VLANs 10/20/30 com tag) ligada à NIC onboard do OptiPlex
- [ ] Configurar a NIC onboard do Proxmox como bridge VLAN-aware (trunk DMZ/Trusted/Management)
- [ ] Configurar o adaptador USB→RJ45 como bridge separada, sem tags (perna WAN, ligada à rede de casa/router)
- [ ] Criar a VM de firewall dedicada (OPNsense ou pfSense), com uma interface por zona (WAN, DMZ, Trusted, Management)
- [ ] Configurar regras do firewall: DMZ→Trusted só nas portas necessárias; DMZ→Management bloqueado; WAN-side→Management só a partir do IP do PC do Rui; túnel WireGuard→Trusted+Management permitido
- [ ] Atualizar o port-forward do router: passa a apontar para a perna WAN-side da VM de firewall (não diretamente para o Caddy)
- [ ] Exportar e guardar a configuração da firewall (ex.: `config.xml` do OPNsense) como parte do backup - perder isto é perder toda a política de rede, não só "um serviço"

## Fase 2 - Serviços base

- [ ] Provisionar VM TrueNAS no Proxmox (zona Trusted) e passar o HDD 1TB (passthrough de disco, atualmente na bay USB TooQ) - ver [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md#plano-de-instalacao-resumo)
- [ ] No TrueNAS, importar o pool ZFS existente da NAS antiga (v1) - **não formatar**, o disco já tem dados
- [ ] Confirmar/ajustar datasets e partilhas SMB/NFS no TrueNAS (`apps`, `cloud`, `media`, `backups`)
- [ ] Instalar/recriar WireGuard (zona DMZ, gera acesso à zona Trusted) - decidir se reaproveita DDNS da v1 ou cria novo
- [ ] Instalar Caddy (zona Trusted, por agora só HTTPS interno via VPN - sem perna DMZ até haver uma app decidida para exposição pública)
- [ ] Instalar Nextcloud (zona Trusted, **só acesso via WireGuard** - decidido 22/07/2026, não expor publicamente), com storage a apontar para o TrueNAS
- [ ] Instalar/recriar Jellyfin (zona Trusted, mesmo padrão da v1: só via WireGuard), com storage a apontar para o TrueNAS
- [ ] Automatizar backups para o SSD externo 1TB e testar um restore completo

## Fase 3 - Storage / RAID (mais tarde)

- [ ] Comprar 2x HDD NAS iguais (4TB ou 6TB)
- [ ] Migrar para ZFS mirror (RAID1) no TrueNAS

## Fase 4 - IaC e Kubernetes

Ver [PLANO_FERRAMENTAS_E_BOAS_PRATICAS.md §4-5](PLANO_FERRAMENTAS_E_BOAS_PRATICAS.md#4-infrastructure-as-code) para a justificação de cada escolha.

- [ ] Scaffold do repo: `infra/opentofu`, `infra/ansible`, `infra/kubernetes`
- [ ] Criar utilizador/role dedicado + API token no Proxmox para o OpenTofu (nunca `root@pam`)
- [ ] Workflow de GitHub Actions a validar `infra/` (`tofu fmt`/`validate`, `ansible-lint`, `helm lint`) - antes do primeiro `apply` real
- [ ] Provisionar a VM TrueNAS via OpenTofu (substituir o passo manual da Fase 2)
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
- [ ] Confirmar destino/desligamento do PC antigo (v1) após o v2 estar operacional

## Histórico

- 22/07/2026: criado este documento, consolidando "Próximos Passos" (README.md), "Pendências" (PROJECT_CONTEXT.md) e "Sequência de execução recomendada" (PLANO_FERRAMENTAS_E_BOAS_PRATICAS.md §5) num único checklist com estado.
- 22/07/2026: revisão de hardware - corrigido o passo do HDD (bay TooQ) para deixar claro que é preciso importar o pool ZFS existente, não formatar; adicionada decisão em aberto sobre a topologia de rede do adaptador USB->RJ45 + switch TL-SG608E.
- 22/07/2026: correção - o TL-SG608E tinha sido descrito como "unmanaged, sem VLANs"; confirmado (datasheet oficial TP-Link) que é um Easy Smart Switch gerido com suporte a VLAN 802.1Q. Corrigido em [PROJECT_CONTEXT.md §Rede e Segmentação](PROJECT_CONTEXT.md#rede-e-segmentacao-vlans--firewall).
- 22/07/2026: consolidada a arquitetura de rede completa - nova Fase 1 "Rede e Segmentação" (VLANs 10/DMZ, 20/Trusted, 30/Management + VM de firewall dedicada), Nextcloud e Jellyfin decididos como Trusted-only (só via WireGuard), e nova decisão em aberto sobre qual app expor via DMZ. Fases seguintes renumeradas (+1).
- 28/07/2026: novo requisito - VM Linux para programar e testar agentes/LLMs (modelos locais + APIs externas). Adicionadas duas decisões em aberto: zona de rede desta VM, e confirmar o teto real de RAM do OptiPlex (o pressuposto de 32GB pode não chegar).
- 29/07/2026: criado `docs/ESQUEMA_LOGICO_REDE.md`; link da Fase 1 atualizado para apontar para lá em vez de só para o PROJECT_CONTEXT.md.
- 29/07/2026: auditoria da documentação. Adicionada decisão em aberto sobre onde corre o Healthchecks.io (dentro ou fora do k3s). Corrigido o uso do travessão longo por hífen simples em todo o documento.
