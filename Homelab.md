---
tags: [homelab, moc]
---

# Homelab v2

Nota principal (MOC - *map of content*) do projeto. Começa sempre por aqui.

## Estado e decisões
- [Contexto e histórico do projeto](docs/PROJECT_CONTEXT.md) - objetivo, arquitetura, estado atual e decisões.
- [Checklist de implementação](docs/CHECKLIST.md) - estado (feito/pendente) de todas as tarefas, por fase.
- [Esquema lógico de rede](docs/NETWORK.md) - estado atual vs alvo, VLANs, inventário de componentes, regras entre zonas e caminhos de pacote ponta a ponta.
- [Esquema de dados e storage](docs/STORAGE.md) - do disco físico ao container: ZFS, NFS, bind mounts, backup e dependências de arranque.
- [Shortlist de hardware](docs/HARDWARE.md) - critérios e opções consideradas para o host.
- `docs/SECRETS.md` - acessos, tokens e caminhos. **Só existe nesta máquina** (gitignored, não aparece no GitHub) - o link não funciona noutro dispositivo sem copiares o ficheiro à parte. Modelo sem valores reais: [SECRETS.example.md](docs/SECRETS.example.md).

## Como trabalhar neste projeto
- [Ferramentas, documentação, monitorização e IaC (plano)](docs/TOOLING.md) - Obsidian, Slack/Uptime Kuma/Healthchecks, OpenTofu/Ansible.
- [Arquitetura e fluxo de trabalho](docs/WORKFLOW.md) - explicação para iniciantes de onde vive cada ferramenta e como tudo se encaixa.

## Serviços
*(ainda vazio - criar uma nota por serviço em `docs/services/` quando o primeiro for instalado, ex.: TrueNAS)*

## Runbooks
*(ainda vazio - criar procedimentos de recuperação em `docs/runbooks/` à medida que os serviços forem ficando estáveis)*

## Histórico
- 18/07/2026: criada esta nota principal, a servir de ponto de entrada no vault do Obsidian.
- 29/07/2026: adicionado link para `docs/SECRETS.md` (local, gitignored) e o respetivo modelo `docs/SECRETS.example.md`.
