# Plano: Ferramentas, Documentação e Boas Práticas (Homelab v2)

Documento de decisão. Cobre: skills/plugins do Claude Code a adotar, gestão de documentação via Obsidian, monitorização com alertas no Slack, e adoção de Infrastructure as Code (IaC). Criado em 18/07/2026, com base em pesquisa e decisões tomadas nesta sessão.

## 0. Decisões desta sessão
- **Obsidian**: o Rui já usa Obsidian (testou noutro projeto). Quer manter grátis — sem Obsidian Sync pago. Sincronização via Git.
- **Monitorização**: self-hosted assim que possível (Uptime Kuma + Healthchecks.io), com alertas no Slack.
- **IaC**: adotar Terraform/OpenTofu + Ansible desde já, mesmo estando no início do v2.

## 1. Claude Code — skills e plugins a adotar

### Já disponíveis (sem instalar nada)
- `schedule` — para lembretes/tarefas recorrentes (ex.: digest periódico de estado do homelab).
- `loop` — para sessões de trabalho iterativas (ex.: ir montando o IaC playbook a playbook).
- `code-review` / `security-review` — **usar sempre antes de aplicar** alterações de Terraform/Ansible que toquem infraestrutura real. Isto é a rede de segurança mais importante ao adotar IaC cedo.
- `verify` — validar que um serviço realmente funciona fim-a-fim (não só que o `terraform apply` ou `ansible-playbook` correu sem erro).

### A instalar/configurar
- **Slack (oficial)**: plugin `slackapi/slack-skills-plugin` (Claude Code + Slack MCP Server, publicado no marketplace oficial). Autenticação via OAuth ao workspace. Dá a Claude capacidade de ler/escrever no Slack diretamente — útil para complementar os alertas automáticos com um resumo em linguagem natural, se quiseres.
- **Terraform/OpenTofu (oficial, HashiCorp)**: "HashiCorp Agent Skills" — traz conhecimento oficial de Terraform/Packer, validação de módulos e inspeção de state. Faz sentido dado que vamos adotar IaC já.
- **Obsidian MCP (via plugin dentro do próprio Obsidian)**: a partir da v4.0 do plugin **Local REST API**, o próprio plugin já expõe um servidor MCP embutido (deixou de precisar de um processo Python/uvx à parte) — setup ~5 minutos. Dá a Claude operações "vault-aware" (backlinks, tags, daily notes, pesquisa pelo grafo), além de simples edição de ficheiros. Opcional para já — o vault vai ser a própria pasta do repo, por isso Claude Code já consegue ler/editar os `.md` diretamente sem isto; vale a pena ligar quando o vault crescer e quiseres tirar partido de tags/backlinks.

### Nota sobre "connectors"
Tentei procurar conectores prontos (Slack, Obsidian) através do sistema de "connectors" do Claude — esse sistema não está disponível/populado neste ambiente (Claude Code CLI). A integração correta aqui é configurar os servidores MCP manualmente (`claude mcp add ...`), não pelos connectors do claude.ai.

### Encontrado mas não recomendado instalar às cegas
- `jmagar/claude-homelab` — marketplace de agentes/skills específico para gestão de homelabs (setup, health checks, dashboard de estado). É um projeto de terceiros — se quiseres experimentar, ler o código primeiro (nomeadamente o que faz com credenciais) antes de dar acesso a ferramentas do teu homelab.

## 2. Documentação — Obsidian

- **O vault é a própria pasta do repositório** `C:\Users\ruigr\Documents\GitHub\homelab`. Obsidian funciona sobre qualquer pasta de Markdown — não é preciso converter nada, os `.md` já existentes funcionam.
- **Sincronização grátis via Git**: instalar o plugin comunitário **obsidian-git** dentro do Obsidian (Settings → Community plugins). Dá um botão de commit/push/pull e pode fazer auto-backup agendado. Assim sincronizas entre dispositivos sem pagar o Obsidian Sync — só precisas de ter o repo clonado em cada máquina/telemóvel (no telemóvel, via app Git ou o próprio Obsidian mobile + Working Copy/Termux, conforme o que já usas).
- **Estrutura recomendada** (evolução do que já existe, não uma reescrita):
  - `Homelab.md` (nota raiz / MOC — *Map of Content*) — substitui/expande o README como ponto de entrada no Obsidian, com links para as notas abaixo.
  - `docs/services/` — uma nota por serviço (Proxmox, TrueNAS, Jellyfin, WireGuard, Uptime Kuma, Healthchecks...), cada uma com: estado atual, configuração-chave, link para o runbook.
  - `docs/runbooks/` — procedimentos de recuperação por serviço ("se X falhar, fazer Y"). Importante para disaster recovery — documentar não é só `PROJECT_CONTEXT.md`, é também "como restauro isto às 2h da manhã".
  - `docs/PROJECT_CONTEXT.md` mantém-se como está — o histórico/decisões recentes já segue o padrão de um log de decisões (bom hábito, continuar).
  - Tags sugeridas: `#pendente`, `#decisão`, `#risco`, `#servico` — para navegares pelo grafo do Obsidian em vez de só pelas pastas.

## 3. Monitorização e alertas — Slack

Dois níveis complementares, os dois self-hosted no próprio homelab, os dois a alertar para um canal Slack dedicado (ex.: `#homelab-alerts`) via **Incoming Webhook** do Slack (mais simples que OAuth só para alertas de saída):

1. **Uptime Kuma** — monitorização "está no ar?" em tempo real (HTTP/TCP/ping/Docker/SSL) para cada serviço (TrueNAS, Jellyfin, WireGuard, router...). Suporta Slack nativamente (um dos 90+ canais de notificação). É o standard de facto para homelabs.
2. **Healthchecks.io (self-hosted)** — "dead man's switch" para jobs agendados (backups, scrub do ZFS, runs do Ansible). Um script termina com um `curl` a um URL único; se o ping falhar/não chegar a horas, alerta. Isto apanha falhas silenciosas que o Uptime Kuma não vê (ex.: "o backup parou de correr há 3 semanas mas o servidor está no ar").
3. *(Mais tarde, não urgente)* Grafana + Prometheus/Netdata para gráficos de CPU/RAM/disco — só quando a base estiver estável e sentires falta de métricas mais profundas.

Complemento opcional via Claude: uma tarefa agendada (skill `schedule`) que corre, por ex., uma vez por dia, consulta a API do Uptime Kuma + as pendências do `PROJECT_CONTEXT.md`, e posta um resumo em linguagem natural no mesmo canal Slack. Isto é um "relatório", não o alerta crítico — o alerta em si (passo 1 e 2) tem de continuar a não depender de nenhuma sessão de LLM a correr.

## 4. Infrastructure as Code

Stack escolhida: **OpenTofu** (fork open-source do Terraform, evita questões de licença) com o provider **`bpg/proxmox`** (o mais ativamente mantido) para provisionar VMs/LXCs; **Ansible** para as configurar por dentro (pacotes, Docker, Uptime Kuma, Healthchecks, Jellyfin, WireGuard).

Estrutura proposta no repo:
```
infra/
├── opentofu/         # provider config + definições de VMs/LXCs
│   └── ...
├── ansible/
│   ├── inventory/
│   └── roles/        # truenas, jellyfin, wireguard, monitoring...
└── secrets/           # nunca commitado em texto plano (ver abaixo)
```

**Segredos**: para já, começar simples — `.gitignore` a cobrir `*.tfvars`, `secrets/`, `*vault.yml`, e manter só ficheiros `.example` versionados como template. Evoluir para SOPS + age (encriptar ficheiros de segredos e podê-los commitar em cifra) quando o volume justificar — não vale a pena a complexidade extra logo no primeiro playbook.

**Proxmox**: criar um utilizador/role dedicado com permissões mínimas e um API token próprio para o OpenTofu usar — nunca `root@pam`.

**Disciplina**: toda a alteração de infraestrutura passa por `code-review`/`security-review` antes de `tofu apply` / `ansible-playbook`, e fica registada no histórico do `PROJECT_CONTEXT.md`.

**Primeira tarefa de IaC** (dado o estado atual — só Proxmox instalado): provisionar a VM TrueNAS via OpenTofu, depois um role Ansible para configurar datasets/partilhas — codificando o que já estava planeado manualmente na Fase 1.

## 5. Sequência de execução recomendada

1. Obsidian: abrir o repo homelab como vault, instalar `obsidian-git`, confirmar sync a funcionar entre dispositivos.
2. Slack: criar canal `#homelab-alerts` e um Incoming Webhook (feito pelo Rui, requer acesso ao workspace).
3. IaC: scaffold de `infra/opentofu` + `infra/ansible`, token de API dedicado no Proxmox, primeira VM (TrueNAS) provisionada por código.
4. Monitorização: LXC com Uptime Kuma (via Ansible), ligado ao webhook do Slack; depois Healthchecks.io self-hosted para os jobs de backup.
5. Claude Code: instalar o plugin Slack oficial e as skills Terraform da HashiCorp; opcionalmente o MCP do Obsidian mais tarde.
6. Grafana/Prometheus — só depois, se sentires falta.

## 6. Notas de segurança
- Nunca commitar tokens/API keys/passwords em texto — nem nos `.tfvars`, nem nos playbooks, nem nas notas do Obsidian se o vault for o repo público... **este repo é privado**, mas mesmo assim, tratar segredos como se pudesse ficar público um dia.
- Webhooks do Slack são, na prática, um "bearer token" — tratar o URL como segredo (não colar em notas partilhadas).
