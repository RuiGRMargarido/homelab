# Segredos e Acessos (modelo)

Este ficheiro é o modelo, versionado no repo, sem nenhum valor real. A versão com os valores verdadeiros é `docs/SEGREDOS.md`, que existe só localmente (está no `.gitignore`, nunca é commitada).

Se estás a configurar este projeto de novo (nova máquina, ou a começar do zero): copia este ficheiro para `docs/SEGREDOS.md` e preenche os valores reais lá.

Para passwords/tokens importantes, o ideal é guardá-los também (ou só) num gestor de passwords (Bitwarden, KeePassXC, etc.) - este ficheiro serve para referência rápida e para os campos que não são segredo em si (URLs, caminhos, nomes de utilizador).

## Infraestrutura base

| Serviço | URL / endereço | Utilizador | Password |
|---|---|---|---|
| Proxmox VE | https://\<ip-do-optiplex\>:8006 | root@pam (ou o utilizador dedicado da Fase 4) | *(ver gestor de passwords)* |
| Router | http://\<ip-do-router\> | | |
| Switch | http://\<ip-do-switch\> | | |

## VMs e Containers (Proxmox) - inclui reserva DHCP

Prática: todo servidor/VM tem reserva DHCP no router (nunca DHCP puramente dinâmico).

| ID | Nome | Tipo | IP | MAC | Reserva feita? | Notas |
|---|---|---|---|---|---|---|
| | | VM/LXC | | | | |

## Acessos administrativos por serviço

| Serviço | Acesso | Utilizador | Password |
|---|---|---|---|
| TrueNAS - interface web | https://\<ip-da-vm-truenas\> | | |
| TrueNAS - SMB/partilhas | \\\\\<ip\>\\ | | |
| VM Firewall (OPNsense/pfSense) | https://\<ip-da-vm-firewall\> | | |
| Nextcloud | https://\<url-interna\> | | |
| Jellyfin | http://\<ip\>:8096 | | |
| Uptime Kuma | http://\<ip\>:3001 | | |
| k3s (kubectl) | *(ver kubeconfig, caminho abaixo)* | | |
| GitHub | github.com/\<utilizador\>/\<repo\> | | *(gerido pelo Git Credential Manager, não precisa de estar aqui)* |

## DNS dinâmico (acesso de fora de casa)

| Campo | Valor |
|---|---|
| Provedor | \<No-IP / DuckDNS / Dynu / outro\> |
| Hostname | |
| Plano | |
| Login da conta | |
| Notas | *(ex.: planos free podem exigir confirmação periódica do hostname)* |

## WireGuard

| Campo | Valor |
|---|---|
| Onde corre | |
| Porta | |
| Rede do túnel | |
| IP do servidor no túnel | |
| Endpoint para clientes | |
| Chave pública do servidor (não secreta) | |
| Chave privada do servidor | *(caminho no servidor, nunca colar aqui)* |
| Configs dos clientes (peers) | *(caminho)* |
| Port-forward no router | |

## Tokens e chaves de API

| O quê | Para que serve | Onde está / valor |
|---|---|---|
| Proxmox API token (OpenTofu) | Fase 4 - permite ao OpenTofu criar/gerir VMs sem usar root@pam | |
| Slack Incoming Webhook | Alertas para #homelab-alerts | *(tratar como password - é um bearer token)* |
| Healthchecks.io (se aplicável) | Ping dos jobs agendados | |

## Ficheiros de chaves (não inlinar o conteúdo aqui, só o caminho)

| O quê | Caminho |
|---|---|
| Chave SSH usada pelo Ansible | |
| Kubeconfig do k3s | |
| `infra/secrets/*.tfvars` (OpenTofu) | `C:\Users\ruigr\Documents\GitHub\homelab\infra\secrets\` (gitignored, ver Fase 4) |

## Datasets e caminhos importantes

| O quê | Caminho |
|---|---|
| Datasets TrueNAS | |
| Ponto de montagem do backup (SSD externo) | |
| Disco(s) em passthrough - caminho `by-id` | |
| Repo homelab (neste PC) | `C:\Users\ruigr\Documents\GitHub\homelab` |
| Repo homelab (no OptiPlex, se aplicável) | |

## Histórico

- 29/07/2026: criado este modelo e o `docs/SEGREDOS.md` (local, gitignored) correspondente.
- 29/07/2026: reestruturado para acompanhar a reorganização do `SEGREDOS.md` (secções separadas para VMs/containers, acessos por serviço, DNS dinâmico, WireGuard).
