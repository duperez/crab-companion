# Crab Companion — guia para o Claude (IA)

Você está no repositório do Crab Companion: um pet de desktop para macOS (caranguejo pixel art em Swift/AppKit) que reflete o estado do Claude Code via hooks e responde permissões/perguntas por balões de fala. O caranguejo se chama **Craby** — use esse nome ao falar dele com o usuário.

## Setup automático

Se o usuário pedir para instalar/configurar, rode:

```bash
./install.sh
```

Isso compila, monta `~/Applications/Crab Companion.app`, registra o LaunchAgent `com.crab-companion.pet` (inicia no login) e adiciona os hooks ao `~/.claude/settings.json` (com backup em `settings.json.crab-backup`; eventos que já tenham hooks do usuário são pulados — nesse caso, mostre ao usuário o hook que faltou e ofereça mesclar manualmente). Depois, peça ao usuário para reiniciar sessões abertas do Claude Code.

Verificação pós-install:

```bash
curl -s localhost:4923/done   # caranguejo comemora; deve responder "ok"
pgrep -fl "Crab Companion"    # processo vivo
```

Requisitos que podem faltar: `xcode-select --install` (swiftc), `brew install jq`.

## Arquitetura (1 minuto)

- `main.swift` — o app inteiro (~700 linhas, sem dependências): janela flutuante borderless (todos os Spaces + fullscreen, `.accessory`), NSStatusItem animado, servidor HTTP em `localhost:4923` (NWListener), máquina de estados idle/working/done/attention com prioridade por sessão, balões de permissão/múltipla escolha/texto livre com long-poll.
- `notify.sh` — chamado pelos hooks UserPromptSubmit/Stop/Notification; extrai `session_id` e `cwd` do stdin e faz GET `/{estado}?session=...&project=...`.
- `ask.sh` — chamado pelo hook PermissionRequest; monta o balão via POST `/ask` e traduz a resposta em `permissionDecision` (formato: `hookSpecificOutput.decision.behavior` allow/deny + `additionalContext` no deny — NÃO use `permissionDecision`, esse é do PreToolUse).
- `make_icon.swift` — gera o PNG do ícone a partir da pixel art.
- Sprites são grades de strings 14x14 (1 char = 1 pixel; palette R/D/W/B/Y/G/L). Estados retornam arrays de quadros; animar = alternar grades.

## Ciclo de desenvolvimento

```bash
swiftc main.swift -o pet          # compilar
./pet                             # rodar avulso (mate com clique direito no pet)
curl localhost:4923/working       # testar estados: working|done|attention|idle
curl localhost:4923/answer/allow  # responder balões programaticamente (allow|deny|ask|opt:N|txt:...)
./install.sh                      # publicar a mudança no app instalado (re-registra o LaunchAgent)
```

Cuidados ao mexer:
- A porta 4923 só aceita uma instância; mate a antiga antes de rodar outra (`curl localhost:4923/quit`).
- Timeouts dos balões: 45s (90s no modo texto) → resposta automática "ask" = fallback pro terminal. Nunca remova esse fallback: o pet não deve decidir sozinho.
- Sons: NSSound "Glass" (done) e "Ping" (attention); respeitam o toggle "Sons" do menu da barra.
- O clique inteligente usa Accessibility (AXRaise) e degrada graciosamente sem a permissão.

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
