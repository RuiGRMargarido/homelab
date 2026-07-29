# Segredos e Acessos (modelo)

Este ficheiro é o modelo, versionado no repo, sem nenhum valor real. A versão com os valores verdadeiros é `docs/SEGREDOS.md`, que existe só localmente (está no `.gitignore`, nunca é commitada).

Se estás a configurar este projeto de novo (nova máquina, ou a começar do zero): copia este ficheiro para `docs/SEGREDOS.md` e preenche os valores reais lá.

Para passwords/tokens importantes, o ideal é guardá-los também (ou só) num gestor de passwords (Bitwarden, KeePassXC, etc.) - este ficheiro serve para referência rápida e para os campos que não são segredo em si (URLs, caminhos, nomes de utilizador).

## Acessos administrativos

| Serviço | URL / endereço | Utilizador | Password / token |
|---|---|---|---|
| Proxmox VE | https://\<ip-do-optiplex\>:8006 | root@pam (ou o utilizador dedicado da Fase 4) | *(ver gestor de passwords)* |
| Router (Vodafone Smart Router) | http://\<ip-do-router\> | | |
| Switch TL-SG608E | http://\<ip-do-switch\> | | |
| TrueNAS | http://\<ip-da-vm-truenas\> | | |
| VM Firewall (OPNsense/pfSense) | https://\<ip-da-vm-firewall\> | | |
| Nextcloud | https://\<url-interna\> | | |
| Jellyfin | http://\<ip\>:8096 | | |
| k3s (kubectl) | *(ver ficheiro kubeconfig, caminho abaixo)* | | |
| Uptime Kuma | http://\<ip\>:3001 | | |
| GitHub | github.com/RuiGRMargarido/homelab | RuiGRMargarido | *(gerido pelo Git Credential Manager, não precisa de estar aqui)* |

## Tokens e chaves de API

| O quê | Para que serve | Onde está / valor |
|---|---|---|
| Proxmox API token (OpenTofu) | Fase 4 - permite ao OpenTofu criar/gerir VMs sem usar root@pam | |
| Slack Incoming Webhook | Alertas do Uptime Kuma/Healthchecks para #homelab-alerts | *(tratar como password - é um bearer token)* |
| Healthchecks.io (se aplicável) | Ping dos jobs agendados | |
| DDNS (provedor e credenciais) | Atualização do domínio dinâmico | |

## Ficheiros de chaves (não inlinar o conteúdo aqui, só o caminho)

| O quê | Caminho |
|---|---|
| Chave privada WireGuard (servidor) | |
| Configs dos clientes WireGuard | |
| Chave SSH usada pelo Ansible | |
| Kubeconfig do k3s | |
| `infra/secrets/*.tfvars` (OpenTofu) | `C:\Users\ruigr\Documents\GitHub\homelab\infra\secrets\` (gitignored, ver Fase 4) |

## Caminhos importantes

| O quê | Caminho |
|---|---|
| Datasets TrueNAS | `/mnt/<pool>/apps`, `/mnt/<pool>/cloud`, `/mnt/<pool>/media`, `/mnt/<pool>/backups` |
| Ponto de montagem do backup (SSD externo) | |
| Disco 1TB (bay TooQ) - caminho `by-id` | |
| Repo homelab (neste PC) | `C:\Users\ruigr\Documents\GitHub\homelab` |
| Repo homelab (no OptiPlex, se aplicável) | |

## Histórico

- 29/07/2026: criado este modelo e o `docs/SEGREDOS.md` (local, gitignored) correspondente.
