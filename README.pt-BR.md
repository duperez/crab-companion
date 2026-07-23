# 🦀 Crab Companion

> Conheça o **Craby** — um caranguejinho em pixel art que vive por cima da tela do seu Mac e te conta o que o Claude Code está fazendo. E deixa você responder sem tocar no terminal.

*Read in [English](README.md) · Site: [duperez.github.io/crab-companion](https://duperez.github.io/crab-companion/)*

<p align="center">
  <img src="docs/demo.gif" width="140" alt="Craby passando pelos estados: ocioso, trabalhando no laptop, comemorando e pedindo atenção">
</p>

Você manda o Claude Code trabalhar em algo demorado, troca de aplicativo e… e agora? Fica dando alt-tab pra conferir? O Craby resolve o problema do "já terminou?" ficando sempre no canto do seu olho:

- 😴 **Ocioso** — garras pro alto, tamborilando devagar, piscando de vez em quando (e se tudo ficar quieto por 10 minutos, ele dorme — Zzz)
- 💻 **Trabalhando** — debruçado num laptopzinho, garras martelando o teclado, teclas voando
- 🎉 **Terminou** — pulando entre faíscas (com um *plim* opcional)
- ❗ **Precisa de você** — acenando com um "!" piscando (com um *ping* opcional)

E o melhor: quando o Claude pede permissão ou tem uma pergunta, um **balão de fala** abre embaixo do Craby e você responde ali mesmo.

## O que ele faz

- **Sempre visível, nunca no caminho** — flutua acima de todos os apps, em todos os Spaces, até sobre apps em tela cheia. Nunca rouba o foco, sem ícone no Dock, invisível ao cmd-tab.
- **Gêmeo na menu bar** — um mini-caranguejo animado na barra superior, sempre em sincronia. Recolha o flutuante pra barra quando precisar de tela limpa (menu "Recolher para a barra").
- **Permissões pelo balão** — quando o Claude Code pede permissão, o balão mostra o que ele quer rodar com botões *Permitir / Negar / Terminal*. Seu clique responde o prompt de verdade, via o hook oficial `PermissionRequest`. Comandos perigosos (`rm`, `push --force`, `sudo`…) ganham borda vermelha. Um quarto botão, **Sempre permitir**, mostra a regra exata que vai criar (ex. `Bash(git *)`) e grava no seu `permissions.allow` do `~/.claude/settings.json` (com backup `.craby-bak`) — treine sua allowlist clicando no caranguejo.
- **Uso do plano de relance** — se houver um token OAuth do Claude Code disponível, o Craby mostra as janelas da sua assinatura (% da sessão de 5h, % da semana) no tooltip e no menu, e ganha uma gota de suor preocupada quando a janela de 5h passa de 80%. Sem token? O recurso some em silêncio. Busca do token: env `CLAUDE_CODE_OAUTH_TOKEN` → `~/.claude/.credentials.json` → `~/Library/Application Support/Craby/oauth-token` (cole ali a saída do `claude setup-token`) → Keychain do macOS.
- **Comemora seus pushes** — `GET /celebrate` (ou `craby celebrate "texto"`) solta confete e um toast. Instale como hook do git com o [`examples/git-hooks/pre-push`](examples/git-hooks/pre-push) e o Craby festeja a cada `git push`.
- **Perguntas pelo balão** — uma API HTTP local permite que o Claude (ou qualquer script) faça perguntas de múltipla escolha ou texto livre pelo balão, com fallback pro terminal.
- **Placar multi-sessão** — várias sessões do Claude Code ao mesmo tempo? O caranguejo mostra o estado de maior prioridade entre todas, com pontinhos brancos para sessões trabalhando em paralelo e um tooltip listando o status de cada projeto. Clicar nele ergue a janela do projeto que precisa de você (requer permissão de Acessibilidade).
- **Uma ninhada de subagentes** — quando o Claude Code dispara subagentes, cada um nasce como um mini-caranguejo numa faixa abaixo do Craby: um ovo racha com um *pop*, as patinhas tamborilam enquanto o subagente roda, e quando ele termina o filhote se aposenta de bengala por uns segundos e some num puf de estrelinhas (*tink*). Subagente que falha ou fica órfão dá um puf cinza/vermelho com um som grave (*basso*) — dá pra distinguir sucesso de falha só de ouvido. Até 5 filhotes visíveis, contagem por sessão no tooltip do Craby ("· N 🐣"), reportado no `GET /status`, alimentado pelos hooks oficiais `SubagentStart`/`SubagentStop`. Até onde sabemos, nenhum outro pet de status de código transforma seus subagentes em filhotes.
- **Sons com temas** — toques discretos pra terminou/atenção/nascimento/puf/level-up, em três temas (Clássico, Suave, Retrô) e com override por evento. Liga/desliga e escolhe o tema nas Preferências.
- **Craby fala** — mini-toasts acima da cabeça dele: bom-dia (com sua sequência de dias), marcos de tarefas, recordes de ninhada e um resumo de uma linha do que cada sessão acabou de terminar (extraído localmente do transcript — nada sai da sua máquina).
- **Janela de Preferências** — tópico ntfy, sons, tema de sons, recolher ao compartilhar tela e mais, sem editar arquivo de configuração (menu → Preferências).
- **CLI `craby`** — `craby status`, `craby ask "pergunta" A B`, `craby input "pergunta"`, `craby done`… toda a API HTTP num comando amigável, instalado no seu PATH.
- **Atualização em um clique** — quando sai versão nova, o menu oferece "Atualizar agora": o Craby baixa o release, se troca e reinicia.
- **Modo apresentação** — some sozinho enquanto sua tela está sendo compartilhada (melhor esforço; configurável nas Preferências).
- **Ele é vivo** — os olhos dele seguem seu mouse pela tela, ele tem manias espontâneas no ócio (um aceninho, um passinho de lado, uma bolhinha), gota de esforço quando a tarefa demora, soneca quando nada acontece e comemoração com confete quando sobe de nível. Do nível 3 em diante, exibe a patente na cabeça: capacete de obra → chapéu de mestre → coroa. No primeiro uso, ele se apresenta.
- **Estatísticas e níveis** — o menu da barra mostra o dia (tarefas concluídas, projetos, tempo trabalhado), sua sequência de dias e os últimos eventos — clique num deles pra pular pra janela daquele projeto. O nível do Craby cresce de *filhote* a *lenda* conforme as tarefas acumulam, e o menu avisa quando sai versão nova.
- **Aviso no celular quando você está longe** — opcional: se ninguém mexe no Mac há 2 minutos e o Claude precisa de você, o Craby avisa seu celular via [ntfy](https://ntfy.sh) (veja Configuração).
- **Arraste pra onde quiser** — pegue e solte o Craby em qualquer lugar; a posição fica salva. Atalhos no balão também: clique nele e aperte 1/2/3 pra escolher ou Esc pro terminal.
- **Sprites customizados** — os sprites são grades de caracteres; um `sprites.json` na pasta de configuração troca o visual inteiro (gato? polvo? PRs bem-vindos).
- **Português, inglês e espanhol** — a interface segue o idioma do sistema.
- **Seguro por padrão** — se você não responder um balão a tempo, tudo cai no prompt normal do terminal. O Craby nunca decide nada sozinho, e os endpoints que *injetam decisões* exigem um token secreto local.

## Instalação

Requisitos: macOS 13+, `jq` (`brew install jq`) e [Claude Code](https://claude.com/claude-code).

**Homebrew**

```bash
brew tap duperez/craby
brew install --cask craby
"/Applications/Craby.app/Contents/Resources/setup.sh"   # conecta o Craby ao Claude Code
```

**Do código-fonte** (precisa também do Xcode Command Line Tools, `xcode-select --install`)

```bash
git clone https://github.com/duperez/crab-companion.git
cd crab-companion
./install.sh
```

**App pronto** — baixe o `Craby.app.zip` nos [Releases](https://github.com/duperez/crab-companion/releases), descompacte em `/Applications`, rode `xattr -dr com.apple.quarantine /Applications/Craby.app` (o app não é assinado) e execute o `setup.sh` que está em `Craby.app/Contents/Resources/`.

Todos os caminhos terminam igual: o app em `Applications/Craby.app` (~300 KB, zero dependências), um LaunchAgent iniciando no login e os hooks do Claude Code no `~/.claude/settings.json` — sua configuração anterior ganha backup, e hooks existentes nos mesmos eventos nunca são sobrescritos. Reinicie as sessões abertas do Claude Code e pronto. Pra remover tudo: `./uninstall.sh`.

## Como funciona

```
Claude Code ── hooks ──> localhost:4923 ──> 🦀 (janela flutuante + menu bar)
     ^                                        │
     └────── decisão (long-poll HTTP) ────────┘
```

O Claude Code dispara [hooks](https://code.claude.com/docs/en/hooks) em eventos do ciclo de vida. Cada hook é um script minúsculo que faz POST pro servidor HTTP local do caranguejo:

| Evento do hook | Reação do caranguejo |
|---|---|
| `UserPromptSubmit` | senta no laptop e digita |
| `PostToolUse` | batimento cardíaco — mantém o "trabalhando" vivo (sessão morta vira ociosa após 10 min sem um) |
| `SubagentStart` / `SubagentStop` | um filhote nasce abaixo do Craby / se aposenta de bengala e dá puf |
| `Stop` | comemora (terminou) |
| `Notification` | acena pedindo atenção |
| `PermissionRequest` | abre o balão de decisão e **espera seu clique** |

O fluxo do `PermissionRequest` é o mais legal: o hook segura a conexão aberta (long-poll) enquanto o balão está na tela. Seu clique volta como stdout do hook — um `permissionDecision` oficial — e o prompt do terminal nem chega a aparecer. Sem resposta em ~45 s? O hook não devolve nada e o prompt normal aparece. O caranguejo nunca aprova nada sozinho.

## API HTTP

Qualquer coisa na sua máquina pode conversar com o caranguejo:

| Endpoint | O que faz |
|---|---|
| `GET /working?session=id&project=nome` | marca uma sessão como trabalhando |
| `GET /done?...` / `GET /attention?...` / `GET /idle?...` | demais estados |
| `POST /ask` `{"title","detail","urgent"}` | balão de permissão (Permitir/Negar/Terminal), long-poll até o clique |
| `POST /ask` `{...,"options":["A","B"]}` | balão de múltipla escolha → responde `opt:0`, `opt:1`… |
| `POST /ask` `{...,"input":true}` | balão de texto livre → responde `txt:<texto digitado>` |
| `GET /status` | JSON com versão, estado exibido, nível e estados por sessão |
| `GET /celebrate?text=...` | confete + toast (ex.: de um hook `pre-push` do git) |
| `GET /answer/<allow\|deny\|ask\|opt:N\|txt:...>` | responde o balão atual programaticamente (**exige token**) |
| `GET /quit` | encerra o app (**exige token**) |

Respostas do balão: `ask` significa "o usuário prefere o terminal" — trate isso (e erros de conexão) sempre como "volte pro fluxo normal".

Os dois endpoints que injetam decisões exigem um segredo, pra que nenhum processo local aleatório aprove coisas por você: passe `?token=$(cat "$HOME/Library/Application Support/Craby/token")` (ou o header `X-Craby-Token`). O token é criado no primeiro uso, legível só pelo seu usuário.

## Configuração

Tudo opcional, tudo em `~/Library/Application Support/Craby/`:

- `config.json` — aviso no celular quando ausente: `{"ntfyTopic": "seu-topico-secreto"}`. Assine o mesmo tópico no [app do ntfy](https://ntfy.sh); o Craby publica lá quando o Claude precisa de você e o Mac está parado há 2+ minutos.
- `sprites.json` — troque o visual: `{"states": {"idle": [[14 strings de 14 chars], …], …}, "palette": {"R": "#e8593d"}}`. Estados omitidos mantêm a arte padrão; grades inválidas são ignoradas.
- `stats.json` — a memória do Craby (tarefas, tempo, eventos). Apague pra resetar o nível dele.

## Funciona com qualquer agente

Os hooks do Claude Code são só um cliente — a API HTTP é agnóstica. Qualquer coisa que rode `curl` pode controlar o Craby: Codex CLI, Gemini CLI, cron, scripts de CI, builds longos. A integração mais simples é o [`examples/craby-run`](examples/craby-run), um wrapper que marca a sessão como trabalhando, roda seu comando e comemora (ou pede atenção se falhar):

```bash
cp examples/craby-run /usr/local/bin/
craby-run npm run build
craby-run codex exec "refatore os testes"
```

Pra integrações mais profundas, use os endpoints diretamente — veja a tabela acima.

## Deixe o Claude te perguntar pelo caranguejo

Adicione isto ao seu `~/.claude/CLAUDE.md` e o Claude vai preferir o balão pra perguntas rápidas:

```markdown
## Perguntas via Crab Companion
Para perguntas curtas de múltipla escolha, antes de usar AskUserQuestion, tente:
curl -s --max-time 50 -X POST -H 'Content-Type: application/json' \
  -d '{"title":"[<projeto>] Claude tem uma pergunta","detail":"<pergunta>","urgent":false,"options":["A","B"]}' \
  http://localhost:4923/ask
Resposta `opt:N` = opção de índice N; `txt:<texto>` = resposta digitada (use `"input":true` no lugar de options);
`ask`/vazio = use AskUserQuestion normalmente.
```

## Desenvolvimento

AppKit puro, sem dependências, em módulos pequenos dentro de [`Sources/`](Sources/): `Sprites.swift` (pixel art + estados), `HTTPServer.swift`, `Stats.swift`, `L10n.swift`, `App.swift`. Os sprites são grades de caracteres — editar o Craby é literalmente editar texto:

```
".RR........RR.",
".RR........RR.",      R corpo   W/B olhos
"..R........R..",      D sombra  Y efeitos
"..RRRRRRRRRR..",      G/L laptop
".RRWBRRRRWBRR.",
```

Ciclo de dev:

```bash
swiftc Sources/*.swift -o pet && ./pet     # rodar avulso
curl localhost:4923/working                # cutucar estados
swiftc Sources/Sprites.swift Sources/HTTPServer.swift Sources/L10n.swift \
  Tests/main.swift -o run_tests && ./run_tests
./install.sh                               # levar a mudança pro app instalado
```

O CI roda build, testes e shellcheck a cada push; uma tag `v*` compila o binário universal e publica o release automaticamente.

## Licença

[MIT](LICENSE) — feito com [Claude Code](https://claude.com/claude-code), claro. 🦀
