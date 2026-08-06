# Plano: Ferramentas, Documentação e Boas Práticas (Homelab v2)

Documento de decisão. Cobre: skills/plugins do Claude Code a adotar, gestão de documentação via Obsidian, monitorização com alertas no Slack, e adoção de Infrastructure as Code (IaC). Criado em 18/07/2026, com base em pesquisa e decisões tomadas nesta sessão. Revisto em 22/07/2026 para dar prioridade às práticas mais representativas de infraestrutura moderna (Kubernetes, observabilidade, CI aplicado a IaC).

## 0. Decisões desta sessão
- **Obsidian**: o Rui já usa Obsidian (testou noutro projeto). Quer manter grátis - sem Obsidian Sync pago. Sincronização via Git.
- **Monitorização**: self-hosted assim que possível (Uptime Kuma + Healthchecks.io + Prometheus/Grafana desde o início, não só mais tarde), com alertas no Slack.
- **IaC**: adotar OpenTofu + Ansible desde já, mesmo estando no início do v2.
- **Kubernetes**: os serviços de aplicação (Jellyfin, Nextcloud, monitorização) passam a correr num cluster **k3s**, não em LXCs/VMs isolados por serviço - ver secção 4.
- **CI**: validação automática do IaC via GitHub Actions antes de qualquer `apply` - ver secção 4.

**Motivo destas 3 mudanças (22/07/2026):** o plano original resolvia o homelab mas evitava as três práticas que mais distinguem infraestrutura moderna de "umas VMs com serviços". Kubernetes não estava previsto de todo, apesar de ser o modelo dominante para correr aplicações; Prometheus/Grafana estava adiado como "não urgente", quando observabilidade é precisamente o que permite perceber o que está a acontecer antes de partir; e havia experiência de CI (GitHub Actions) que não estava a ser aplicada à infraestrutura, onde um erro custa bem mais caro do que num build.

## 1. Claude Code - skills e plugins a adotar

### Já disponíveis (sem instalar nada)
- `schedule` - para lembretes/tarefas recorrentes (ex.: digest periódico de estado do homelab).
- `loop` - para sessões de trabalho iterativas (ex.: ir montando o IaC playbook a playbook).
- `code-review` / `security-review` - **usar sempre antes de aplicar** alterações de Terraform/Ansible que toquem infraestrutura real. Isto é a rede de segurança mais importante ao adotar IaC cedo.
- `verify` - validar que um serviço realmente funciona fim-a-fim (não só que o `terraform apply` ou `ansible-playbook` correu sem erro).

### A instalar/configurar
- **Slack (oficial)**: plugin `slackapi/slack-skills-plugin` (Claude Code + Slack MCP Server, publicado no marketplace oficial). Autenticação via OAuth ao workspace. Dá a Claude capacidade de ler/escrever no Slack diretamente - útil para complementar os alertas automáticos com um resumo em linguagem natural, se quiseres.
- **Terraform/OpenTofu (oficial, HashiCorp)**: "HashiCorp Agent Skills" - traz conhecimento oficial de Terraform/Packer, validação de módulos e inspeção de state. Faz sentido dado que vamos adotar IaC já.
- **Obsidian MCP (via plugin dentro do próprio Obsidian)**: a partir da v4.0 do plugin **Local REST API**, o próprio plugin já expõe um servidor MCP embutido (deixou de precisar de um processo Python/uvx à parte) - setup ~5 minutos. Dá a Claude operações "vault-aware" (backlinks, tags, daily notes, pesquisa pelo grafo), além de simples edição de ficheiros. Opcional para já - o vault vai ser a própria pasta do repo, por isso Claude Code já consegue ler/editar os `.md` diretamente sem isto; vale a pena ligar quando o vault crescer e quiseres tirar partido de tags/backlinks.

### Nota sobre "connectors"
Tentei procurar conectores prontos (Slack, Obsidian) através do sistema de "connectors" do Claude - esse sistema não está disponível/populado neste ambiente (Claude Code CLI). A integração correta aqui é configurar os servidores MCP manualmente (`claude mcp add ...`), não pelos connectors do claude.ai.

### Encontrado mas não recomendado instalar às cegas
- `jmagar/claude-homelab` - marketplace de agentes/skills específico para gestão de homelabs (setup, health checks, dashboard de estado). É um projeto de terceiros - se quiseres experimentar, ler o código primeiro (nomeadamente o que faz com credenciais) antes de dar acesso a ferramentas do teu homelab.

## 2. Documentação - Obsidian

- **O vault é a própria pasta do repositório** `C:\Users\ruigr\Documents\GitHub\homelab`. Obsidian funciona sobre qualquer pasta de Markdown - não é preciso converter nada, os `.md` já existentes funcionam.
- **Sincronização grátis via Git**: instalar o plugin comunitário **obsidian-git** dentro do Obsidian (Settings → Community plugins). Dá um botão de commit/push/pull e pode fazer auto-backup agendado. Assim sincronizas entre dispositivos sem pagar o Obsidian Sync - só precisas de ter o repo clonado em cada máquina/telemóvel (no telemóvel, via app Git ou o próprio Obsidian mobile + Working Copy/Termux, conforme o que já usas).
- **Estrutura recomendada** (evolução do que já existe, não uma reescrita):
  - `Homelab.md` (nota raiz / MOC - *Map of Content*) - substitui/expande o README como ponto de entrada no Obsidian, com links para as notas abaixo.
  - `docs/services/` - uma nota por serviço (Proxmox, TrueNAS, Jellyfin, WireGuard, Uptime Kuma, Healthchecks...), cada uma com: estado atual, configuração-chave, link para o runbook.
  - `docs/runbooks/` - procedimentos de recuperação por serviço ("se X falhar, fazer Y"). Importante para disaster recovery - documentar não é só `PROJECT_CONTEXT.md`, é também "como restauro isto às 2h da manhã".
  - `docs/PROJECT_CONTEXT.md` mantém-se como está - o histórico/decisões recentes já segue o padrão de um log de decisões (bom hábito, continuar).
  - `docs/CHECKLIST.md` (criado 22/07/2026) - estado feito/pendente de todas as tarefas, por fase; o `PROJECT_CONTEXT.md` deixou de duplicar isto.
  - `docs/ESQUEMA_LOGICO_REDE.md` (criado 29/07/2026) - diagrama e referência rápida da arquitetura de rede (VLANs, NICs, regras), à parte do log de decisões.
  - Tags sugeridas: `#pendente`, `#decisão`, `#risco`, `#servico` - para navegares pelo grafo do Obsidian em vez de só pelas pastas.

## 3. Monitorização e alertas - Slack

Três níveis complementares, todos self-hosted no próprio homelab, todos a alertar para um canal Slack dedicado (ex.: `#homelab-alerts`) via **Incoming Webhook** do Slack (mais simples que OAuth só para alertas de saída):

1. **Uptime Kuma** - monitorização "está no ar?" em tempo real (HTTP/TCP/ping/Docker/SSL) para cada serviço (TrueNAS, Jellyfin, WireGuard, router...). Suporta Slack nativamente (um dos 90+ canais de notificação). É o standard de facto para homelabs.
2. **Healthchecks.io (self-hosted)** - "dead man's switch" para jobs agendados (backups, scrub do ZFS, runs do Ansible). Um script termina com um `curl` a um URL único; se o ping falhar/não chegar a horas, alerta. Isto apanha falhas silenciosas que o Uptime Kuma não vê (ex.: "o backup parou de correr há 3 semanas mas o servidor está no ar").
3. **Prometheus + Grafana** - antecipado para a fase inicial (deixou de ser "mais tarde, não urgente"). Justificação: os dois níveis acima respondem a "está no ar?", mas não a "porque é que está lento" nem "isto vem a degradar-se há semanas". Num host com RAM já em sobrecompromisso (ver `PROJECT_CONTEXT.md` §Riscos), saber a tendência de consumo vale mais do que um alerta binário. Correr dentro do cluster k3s (secção 4) via `kube-prometheus-stack` (Helm chart) é praticamente imediato - node/cAdvisor exporters + dashboards prontos, sem trabalho de configuração manual significativo, e dá gráficos de CPU/RAM/disco/rede por VM e por pod.

Complemento opcional via Claude: uma tarefa agendada (skill `schedule`) que corre, por ex., uma vez por dia, consulta a API do Uptime Kuma + as pendências do `PROJECT_CONTEXT.md`, e posta um resumo em linguagem natural no mesmo canal Slack. Isto é um "relatório", não o alerta crítico - o alerta em si (passo 1 e 2) tem de continuar a não depender de nenhuma sessão de LLM a correr.

## 4. Infrastructure as Code

Stack escolhida: **OpenTofu** com o provider **`bpg/proxmox`** (o mais ativamente mantido) para provisionar VMs/LXCs; **Ansible** para as configurar por dentro (pacotes, Docker, k3s, TrueNAS); **k3s** (Kubernetes leve) para correr os serviços de aplicação em vez de um LXC por serviço.

### Porquê OpenTofu e não Terraform

Usamos OpenTofu em vez do Terraform "oficial" da HashiCorp por três razões, mas a competência que se aprende é a mesma:

- **Licenciamento**: em 2023 a HashiCorp mudou a licença do Terraform de MPL (open-source) para BSL (Business Source License), que restringe usos comerciais que "compitam" com produtos HashiCorp. A Linux Foundation, com o apoio de dezenas de empresas (AWS, Oracle, Harness, Spacelift...), fez fork do último código MPL e criou o **OpenTofu** - mantém-se 100% open-source, sob governação neutra (não de uma única empresa).
- **Compatibilidade total**: OpenTofu usa a mesma linguagem (HCL), o mesmo formato de state e os mesmos providers do registry do Terraform (incluindo o `bpg/proxmox`). Um ficheiro `.tf` escrito para OpenTofu corre em Terraform e vice-versa - não há nada de "diferente" a aprender.
- **Sem risco de licença num repo pessoal**: mesmo sendo um projeto pessoal, evita qualquer ambiguidade futura se este código vier a ser reutilizado, mostrado num portefólio público, ou adaptado para uso profissional.

**Para o CV/portefólio**: a estratégia de carreira pede "Terraform" como skill (é o nome que recrutadores procuram) - no CV/LinkedIn é correto e recomendado escrever **"Terraform (via OpenTofu)"** ou "Infrastructure as Code com Terraform/OpenTofu (HCL)", já que a experiência prática - escrever HCL, gerir state, providers, módulos - transfere 1:1. O comando `tofu` é apenas um binário diferente do `terraform`, com a mesma sintaxe.

### Kubernetes (k3s) em vez de LXCs por serviço

Em vez de um LXC/VM Ansible por serviço (`jellyfin`, `nextcloud`, `monitoring`...), os serviços de aplicação passam a correr como workloads num cluster **k3s** - distribuição de Kubernetes leve, feita para exatamente este cenário (single-node ou poucos nós, hardware modesto). TrueNAS continua como VM dedicada (faz sentido correr "bare", fora do cluster, por causa do passthrough de disco).

- **Provisionamento**: OpenTofu cria as VMs base (ex.: 1–3 nós k3s); Ansible instala o k3s nelas (role `k3s-server`/`k3s-agent`, ou o role comunitário `k3s-io/k3s-ansible`).
- **Serviços**: cada serviço (Jellyfin, Nextcloud, Uptime Kuma, Prometheus/Grafana) passa a ser um manifest/Helm chart em `infra/kubernetes/`, aplicado com `kubectl apply` ou `helm install` - não mais um role Ansible próprio por serviço.
- **Porquê agora e não mais tarde**: adotar Kubernetes depois de ter cinco serviços a correr em LXCs à mão significa migrá-los todos, e cada migração é uma oportunidade de partir algo que funcionava. Entrar cedo, enquanto o custo de refazer ainda é baixo, é mais barato do que entrar tarde. O homelab é também o sítio certo para errar: uma configuração má aqui não tem custo de produção.

Estrutura proposta no repo:
```
infra/
├── opentofu/         # provider config + definições de VMs (incl. nós k3s)
│   └── ...
├── ansible/
│   ├── inventory/
│   └── roles/        # truenas, k3s-server, k3s-agent, base...
├── kubernetes/
│   ├── truenas-storage/   # StorageClass / PV ligados ao TrueNAS (NFS/iSCSI)
│   ├── jellyfin/          # manifests ou values.yaml de Helm chart
│   ├── nextcloud/
│   └── monitoring/        # kube-prometheus-stack (Prometheus+Grafana) + Uptime Kuma
└── secrets/           # nunca commitado em texto plano (ver abaixo)
```

**Segredos**: para já, começar simples - `.gitignore` a cobrir `*.tfvars`, `secrets/`, `*vault.yml`, `*values-secret.yaml`, e manter só ficheiros `.example` versionados como template. Evoluir para SOPS + age (encriptar ficheiros de segredos e podê-los commitar em cifra) quando o volume justificar - não vale a pena a complexidade extra logo no primeiro playbook.

**Proxmox**: criar um utilizador/role dedicado com permissões mínimas e um API token próprio para o OpenTofu usar - nunca `root@pam`.

**Disciplina**: toda a alteração de infraestrutura passa por `code-review`/`security-review` antes de `tofu apply` / `ansible-playbook` / `kubectl apply`, e fica registada no histórico do `PROJECT_CONTEXT.md`.

### CI: validação automática do IaC (GitHub Actions)

Antes de qualquer `apply` real, um workflow de GitHub Actions corre em cada PR/push que toque `infra/`:
- `tofu fmt -check` + `tofu validate` (e `tofu plan` só de leitura, sem credenciais de apply, se viável correr contra um workspace de plan).
- `ansible-lint` sobre os playbooks/roles.
- `kubeval`/`kubeconform` ou `helm lint` sobre os manifests em `infra/kubernetes/`.

Isto não substitui `code-review`/`security-review` (continuam obrigatórios antes de aplicar), mas apanha erros mecânicos (sintaxe, formatação, más práticas óbvias) automaticamente e sem custo. A diferença face a CI sobre código de aplicação é o custo do erro: um `tofu apply` mal formado não falha um teste, destrói uma VM.

**Primeira tarefa de IaC** (dado o estado atual - só Proxmox instalado): provisionar a VM TrueNAS via OpenTofu, depois provisionar 1 VM e instalar k3s nela via Ansible (cluster de nó único para começar) - codificando o que já estava planeado manualmente na Fase 1, mas já com Kubernetes como destino dos serviços.

## 5. Sequência de execução recomendada

1. Obsidian: abrir o repo homelab como vault, instalar `obsidian-git`, confirmar sync a funcionar entre dispositivos.
2. Slack: criar canal `#homelab-alerts` e um Incoming Webhook (feito pelo Rui, requer acesso ao workspace).
3. IaC (scaffold): `infra/opentofu` + `infra/ansible` + `infra/kubernetes`, token de API dedicado no Proxmox, primeira VM (TrueNAS) provisionada por código.
4. CI: workflow de GitHub Actions a validar `infra/` (`tofu fmt`/`validate`, `ansible-lint`, `helm lint`) antes mesmo do primeiro `apply` real - assim já nasce com a rede de segurança.
5. Kubernetes: provisionar 1 VM via OpenTofu + instalar k3s via Ansible (cluster de nó único).
6. Monitorização: `kube-prometheus-stack` (Prometheus+Grafana) e Uptime Kuma como workloads no k3s, ligados ao webhook do Slack; depois Healthchecks.io self-hosted para os jobs de backup.
7. Serviços de aplicação: migrar Jellyfin/Nextcloud para manifests/Helm no k3s, com storage a apontar para o TrueNAS.
8. Claude Code: instalar o plugin Slack oficial e as skills Terraform da HashiCorp; opcionalmente o MCP do Obsidian mais tarde.

## 6. Notas de segurança
- Nunca commitar tokens/API keys/passwords em texto - nem nos `.tfvars`, nem nos playbooks, nem nas notas do Obsidian se o vault for o repo público... **este repo é privado**, mas mesmo assim, tratar segredos como se pudesse ficar público um dia.
- Webhooks do Slack são, na prática, um "bearer token" - tratar o URL como segredo (não colar em notas partilhadas).
- **Referência de acessos e segredos (criado 29/07/2026)**: `docs/SEGREDOS.md` guarda os acessos administrativos, tokens e caminhos de todos os serviços - existe só localmente (`.gitignore`), nunca é commitado. O modelo sem valores reais, `docs/SEGREDOS.example.md`, esse sim está no repo, e documenta a estrutura. Para passwords realmente importantes (Proxmox, router, firewall), o ideal a prazo é um gestor de passwords - o `SEGREDOS.md` é para referência rápida, não o cofre principal.
