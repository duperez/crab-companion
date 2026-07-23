# Crab Companion — guia para o Claude (IA)

Você está no repositório do Crab Companion: um pet de desktop para macOS (caranguejo pixel art em Swift/AppKit) que **observa o workflow de desenvolvimento** do usuário. Ele é uma *interface de presença*: qualquer "cérebro" local (Claude Code via hooks, addons de CI/containers, scripts) usa o pet como rosto através do protocolo HTTP aberto em `localhost:4923` — o contrato está em **[PROTOCOL.md](PROTOCOL.md)**. O Claude Code é a integração-bandeira. O caranguejo se chama **Craby** — use esse nome ao falar dele com o usuário.

## Leis do projeto (não negocie sem o usuário)

1. **Cenas são do app, props são dos addons.** O catálogo de cenas (poses do corpo) vive em `Sources/Scenes.swift` e só cresce por mudança no app. Addons nunca definem cenas: escolhem uma do catálogo e declaram props (grades JSON) carimbados nos slots dela.
2. **Figurino exclusivo, nunca misturado.** A fonte ativa de maior prioridade (`sourcePriority`; `claude` sempre primeiro no working) veste o pet com sua cena+props. Jamais combine props de fontes diferentes ao mesmo tempo.
3. **Urgência tem vocabulário único.** `state=attention` e `watch status=dead` são o único jeito de pedir o usuário — não invente estados, sons ou animações extras de alarme. Atenção é cara; o resto é done+toast.
4. **Addon nunca recebe o token.** O supervisor entrega só `CRABY_PORT` e `CRABY_SOURCE`. O token (`~/Library/Application Support/Craby/token`) fica restrito aos endpoints que injetam decisões (`/answer`, `/quit`).
5. **Personalidade, não personalização.** Nada de níveis, chapéus por rank, streaks ou cosméticos desbloqueáveis (removidos na v2). O charme vem de comportamento vivo, não de progressão.
6. **Arte: o corpo canônico é o do "done".** Todas as cenas partem do mesmo corpo (domo 8/10/12/10, olhos em talo, garras-mão) — entre cenas só membros/olhos mudam de pose. Não redesenhe o domo por cena.
7. **O pet nunca decide sozinho.** Balões sem resposta caem no terminal (timeout 45s / 90s no texto). Nunca remova esse fallback.

## Setup automático

Se o usuário pedir para instalar/configurar, rode:

```bash
./install.sh
```

Isso compila, monta `~/Applications/Craby.app`, registra o LaunchAgent `com.crab-companion.pet` (inicia no login) e adiciona os hooks ao `~/.claude/settings.json` (com backup em `settings.json.crab-backup`; eventos que já tenham hooks do usuário são pulados — nesse caso, mostre ao usuário o hook que faltou e ofereça mesclar manualmente). Depois, peça ao usuário para reiniciar sessões abertas do Claude Code.

Verificação pós-install:

```bash
curl -s localhost:4923/done   # caranguejo comemora; deve responder "ok"
pgrep -fl "Craby.app"         # processo vivo
```

Requisitos que podem faltar: `xcode-select --install` (swiftc), `brew install jq`.

## Arquitetura (1 minuto)

- `Sources/Scenes.swift` — motor de CENAS+PROPS+SLOTS. Cena = pose do corpo (quadros completos 14x14) + slots de ancoragem nomeados (`cabeca`, `mesa`, `garra`, `chao`, `ceu`, `acima`…). Prop = grade pequena carimbada num slot ("." transparente), com camada frente/trás (`behind`) e âncora por quadro. Catálogo: `idle`, `debrucado` (working, laptop é um prop ATRÁS das mãos), `atento` (vigília, cena padrão dos addons), `comemorando`, `deitado`, `atencao` (sem slots de addon).
- `Sources/Sprites.swift` — pixel art (grades de strings, 1 char = 1 pixel, paleta), carregamento de sprites customizados (`sprites.json`).
- `Sources/Addons.swift` — supervisor de addons: descobre pastas em `~/Library/Application Support/Craby/addons/` (as embutidas em `addons/` do repo são SEMENTES copiadas pra lá na primeira execução), roda o exec por intervalo (mín 5s, primeira execução imediata ao ligar), watchdog de 60s, env `CRABY_PORT`/`CRABY_SOURCE`, resolve o figurino da fonte vencedora.
- `Sources/HTTPServer.swift` — servidor em `localhost:4923` (NWListener). `/answer/*` e `/quit` exigem token (`?token=` ou header `X-Craby-Token`).
- `Sources/Playground.swift` — página servida em `http://localhost:4923`: botões pra todos os endpoints + construtor visual de addons (usa `GET /scenes`).
- `Sources/PlanUsage.swift` — janelas de uso do plano Claude (5h/semana) via token OAuth; some em silêncio sem token.
- `Sources/App.swift` — janela flutuante borderless (todos os Spaces + fullscreen, `.accessory`, arrastável com posição persistida), NSStatusItem animado com menu dinâmico (stats do dia, eventos, submenu 🧩 Addons com liga/desliga + abrir pasta), balões de permissão/múltipla escolha/texto livre com long-poll e atalhos (1/2/3/Esc), legenda de atenção nomeando o chamador, clique abre URL/ergue janela, multi-sessão e multi-fonte com prioridade, ninhada de subagentes, toasts, modo ausente via ntfy, `GET /scenes`.
- `Sources/Stats.swift` — estatísticas diárias e registro de eventos (`stats.json`).
- `Sources/Sounds.swift` — sons por evento (done/attention/hatch/poof) com temas.
- `Sources/L10n.swift` — strings EN/PT/ES (segue o idioma do sistema).
- `addons/` — sementes de fábrica: `github-watch` (CI via `gh`, `repos.txt`) e `live-watch` (portas/PIDs/containers, `targets.txt`). Cada uma: `addon.json` + `run.sh`.
- `notify.sh` — chamado pelos hooks UserPromptSubmit/PostToolUse (heartbeat)/Stop/Notification; extrai `session_id` e `cwd` do stdin e faz GET `/{estado}?session=...&project=...`. Sessões "working" sem evento há 10min são consideradas mortas e viram idle.
- `ask.sh` — chamado pelo hook PermissionRequest; monta o balão via POST `/ask` e traduz a resposta em decisão (formato: `hookSpecificOutput.decision.behavior` allow/deny + `additionalContext` no deny — NÃO use `permissionDecision`, esse é do PreToolUse).
- `PROTOCOL.md` — o contrato dos clientes externos (eventos, watches, ask, addons). Mudou endpoint ou manifesto? Atualize lá.
- `package.sh` monta `dist/Craby.app`; `setup.sh` (embarcado no bundle) registra LaunchAgent + hooks; `tools/main.swift` renderiza ícone e quadros do GIF de demo.

## Ciclo de desenvolvimento

```bash
swiftc Sources/*.swift -o pet     # compilar
./pet                             # rodar avulso (mate com clique direito no pet)
curl localhost:4923/working       # testar estados: working|done|attention|idle
open http://localhost:4923        # playground: endpoints + construtor de addons
TOKEN=$(cat "$HOME/Library/Application Support/Craby/token")
curl "localhost:4923/answer/allow?token=$TOKEN"  # responder balões (allow|deny|ask|opt:N|txt:...)
swiftc Sources/Sprites.swift Sources/Scenes.swift Sources/HTTPServer.swift \
  Sources/L10n.swift Sources/Sounds.swift Sources/Stats.swift \
  Sources/PlanUsage.swift Tests/main.swift -o run_tests && ./run_tests    # testes
./install.sh                      # publicar a mudança no app instalado (re-registra o LaunchAgent)
```

Cuidados ao mexer:
- A porta 4923 só aceita uma instância; mate a antiga antes de rodar outra (`curl localhost:4923/quit` com token).
- Timeouts dos balões: 45s (90s no modo texto) → resposta automática "ask" = fallback pro terminal (lei 7).
- Sons respeitam o toggle "Sons" do menu da barra.
- O clique inteligente usa Accessibility (AXRaise) e degrada graciosamente sem a permissão.
- PROTOCOL.md é v1: campos só entram, nunca saem ou mudam de nome.

## Convenção: perguntar pelo pet

Com o pet instalado, prefira o balão para perguntas curtas ao usuário (múltipla escolha ou resposta curta em texto), em vez de AskUserQuestion:

```bash
curl -s --max-time 50 -X POST -H 'Content-Type: application/json' \
  -d '{"title":"[<projeto>] Claude tem uma pergunta","detail":"<pergunta>","urgent":false,"options":["A","B"]}' \
  http://localhost:4923/ask
# texto livre: troque "options" por "input": true (use --max-time 90)
```

Resposta `opt:N` → opção N (base 0). `txt:<texto>` → resposta digitada. `ask`, vazio ou erro → use AskUserQuestion normalmente. `urgent:true` só para decisões críticas. Se o usuário gostar, ofereça adicionar essa convenção ao `~/.claude/CLAUDE.md` dele (veja o snippet no README).

## Solução de problemas

- Pet não aparece: `launchctl print gui/$UID/com.crab-companion.pet`; recarregue com `launchctl kickstart -k gui/$UID/com.crab-companion.pet`.
- Hooks não disparam: valide `jq -e '.hooks | keys' ~/.claude/settings.json`; sessões abertas antes do install precisam ser reiniciadas (ou o usuário roda `/hooks` uma vez).
- Balão não responde permissões: confira se `ask.sh` do bundle é executável e se a saída é o JSON de `PermissionRequest` (não o de PreToolUse).
- Addon não roda: confira se o exec tem bit de execução, se o manifesto tem `name` e `exec`, e se o addon está ligado no submenu 🧩 Addons. Log de erro sai no Console (`craby:`).
