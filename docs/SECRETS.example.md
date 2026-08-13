# Segredos e Acessos (modelo)

Este ficheiro é o modelo, versionado no repo, sem nenhum valor real. A versão com os valores verdadeiros é `docs/SECRETS.md`, que existe só localmente (está no `.gitignore`, nunca é commitada).

Se estás a configurar este projeto de novo (nova máquina, ou a começar do zero): copia este ficheiro para `docs/SECRETS.md` e preenche os valores reais lá.

Para passwords/tokens importantes, o ideal é guardá-los também (ou só) num gestor de passwords (Bitwarden, KeePassXC, etc.) - este ficheiro serve para referência rápida e para os campos que não são segredo em si (URLs, caminhos, nomes de utilizador).

## Índice

- [Infraestrutura base](#infraestrutura-base)
- [VMs e Containers (Proxmox)](#vms-e-containers-proxmox---inclui-reserva-dhcp)
- [Acessos administrativos por serviço](#acessos-administrativos-por-serviço)
- [Serviço com vários utilizadores (modelo)](#nome-do-serviço-com-vários-utilizadores-ou-configuração-própria-ex-truenas-nextcloud-jellyfin)
- [WireGuard](#wireguard)
- [DNS dinâmico](#dns-dinâmico-acesso-de-fora-de-casa)
- [Tokens e chaves de API](#tokens-e-chaves-de-api)
- [Ficheiros de chaves](#ficheiros-de-chaves-não-inlinar-o-conteúdo-aqui-só-o-caminho)
- [Datasets e caminhos importantes](#datasets-e-caminhos-importantes)
- [Histórico](#histórico)

## Infraestrutura base

| Serviço | URL / endereço | Utilizador | Password |
|---|---|---|---|
| Proxmox VE | https://\<ip-do-optiplex\>:8006 | root@pam (ou o utilizador dedicado da Fase 4) | *(ver gestor de passwords)* |
| Router | http://\<ip-do-router\> | | |
| Switch | http://\<ip-do-switch\> | | |

## VMs e Containers (Proxmox) - inclui reserva DHCP

Prática: todo servidor/VM tem IP estático configurado localmente (`/etc/network/interfaces`), mais reserva DHCP no router como documentação/consistência (nunca depender só de DHCP dinâmico - o lease pode expirar sem renovar sozinho).

| ID | Nome | Tipo | IP | MAC | Reserva feita? | Notas |
|---|---|---|---|---|---|---|
| | | VM/LXC | | | | |

## Acessos administrativos por serviço

Tabela central com um acesso principal por serviço. Para serviços com mais do que uma conta, a última coluna liga para a lista completa na secção própria do serviço (ver exemplo abaixo).

| Serviço | Acesso | Utilizador (principal) | Password | Todas as contas |
|---|---|---|---|---|
| \<Serviço com uma só conta\> | | | | - |
| \<Serviço com várias contas\> | | | | [Contas →](#contas-de-utilizador-nome-do-servico) |
| VM Firewall (OPNsense/pfSense) | https://\<ip-da-vm-firewall\> | | | - |
| Uptime Kuma | http://\<ip\>:3001 | | | - |
| k3s (kubectl) | *(ver kubeconfig, caminho abaixo)* | | | - |
| GitHub | github.com/\<utilizador\>/\<repo\> | | *(gerido pelo Git Credential Manager, não precisa de estar aqui)* | - |

## \<Nome do serviço com vários utilizadores ou configuração própria\> (ex.: TrueNAS, Nextcloud, Jellyfin)

Cria uma secção destas para cada serviço que tenha mais do que um utilizador, ou configuração suficiente para justificar uma secção própria (segue o padrão do WireGuard abaixo). Serviços simples (só uma consola root) ficam só na tabela genérica "Acessos administrativos por serviço".

| Campo | Valor |
|---|---|
| Onde corre | |
| Acesso | |

### Contas de utilizador (Nome do Serviço)

Inclui o nome do serviço no título (ex. "Contas de utilizador (Nextcloud)"), para a ligação a partir da tabela central não depender da ordem das secções no documento.

| Utilizador | Password | Notas |
|---|---|---|
| | | |

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

### Peers (clientes)

| Nome | IP no túnel | Ficheiro no servidor |
|---|---|---|

## DNS dinâmico (acesso de fora de casa)

| Campo | Valor |
|---|---|
| Provedor | \<No-IP / DuckDNS / Dynu / outro\> |
| Hostname | |
| Plano | |
| Login da conta | |
| Notas | *(ex.: planos free podem exigir confirmação periódica do hostname)* |

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

- 29/07/2026: criado este modelo e o `docs/SECRETS.md` (local, gitignored) correspondente.
- 29/07/2026: reestruturado para acompanhar a reorganização do `SECRETS.md` (secções separadas para VMs/containers, acessos por serviço, DNS dinâmico, WireGuard).
- 31/07/2026: reestruturado outra vez - prática de IP estático (não só DHCP) para VMs/LXCs; serviços com vários utilizadores passam a ter secção própria com sub-tabela "Contas de utilizador" (padrão do WireGuard "Peers"), em vez de linhas repetidas na tabela genérica.
- 01/08/2026: "Acessos administrativos por serviço" volta a ser a tabela central (uma linha por serviço), logo a seguir a "VMs e Containers", com uma coluna "Todas as contas" a ligar para a sub-tabela de cada serviço. Títulos "### Contas de utilizador" passam a incluir o nome do serviço entre parênteses.
