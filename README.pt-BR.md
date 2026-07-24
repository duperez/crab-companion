# 🦀 Crab Companion

<p align="center">
  <img src="docs/demo.gif" width="140" alt="Craby passando pelas cenas: ocioso, trabalhando no laptop, comemorando e pedindo atenção">
</p>

O **Craby** é um caranguejinho em pixel art que vive por cima da tela do seu Mac e observa o seu workflow de desenvolvimento. Ele é uma **interface de presença**: um pet de desktop que qualquer "cérebro" local pode usar como rosto — o Claude Code é a integração-bandeira, e o [protocolo](PROTOCOL.md) é aberto, então qualquer coisa que rode `curl` pode controlá-lo. Ele resolve o problema do "já terminou?" morando no canto do seu olho:

- 😴 **Ocioso** — garras pro alto, tamborilando devagar; dez minutos de silêncio e ele deita pra dormir
- 💻 **Trabalhando** — debruçado num laptopzinho, martelando o teclado
- 🔍 **De vigília** — de pé, atento, vigiando algo vivo (CI, um servidor, um container)
- 🎉 **Terminou** — pinças pro alto, confete
- ❗ **Precisa de você** — acenando com um "!" piscando, e uma legendinha dizendo exatamente quem chama

Site: [duperez.github.io/crab-companion](https://duperez.github.io/crab-companion/) · Read in [English](README.md)

## Instalação

```bash
brew tap duperez/craby
brew install --cask craby
"/Applications/Craby.app/Contents/Resources/setup.sh"   # conecta o Craby ao Claude Code
```

Requisitos: macOS 13+, `jq` (`brew install jq`) e [Claude Code](https://claude.com/claude-code). Reinicie as sessões abertas do Claude Code e pronto. Pra remover tudo: `./uninstall.sh`.

<details>
<summary>Outras formas de instalar</summary>

**Do código-fonte** (precisa também do Xcode Command Line Tools, `xcode-select --install`):

```bash
git clone https://github.com/duperez/crab-companion.git
cd crab-companion
./install.sh
```

**App pronto** — baixe o `Craby.app.zip` nos [Releases](https://github.com/duperez/crab-companion/releases), descompacte em `/Applications`, rode `xattr -dr com.apple.quarantine /Applications/Craby.app` (o app não é assinado) e execute o `setup.sh` que está em `Craby.app/Contents/Resources/`.

Todos os caminhos terminam igual: o app em `Applications/Craby.app` (zero dependências), um LaunchAgent iniciando no login e os hooks do Claude Code no `~/.claude/settings.json` — sua configuração anterior ganha backup, e hooks existentes nos mesmos eventos nunca são sobrescritos.

</details>

## Direto da caixa

Instalou e tudo isso já está ligado — zero configuração:

- **Os estados seguem suas sessões** — os [hooks](#hooks-do-claude-code) do Claude Code o comandam: digita quando você manda um prompt, comemora ao terminar, acena quando algo precisa de você.
- **Permissões pelo balão** — quando o Claude pede permissão, o balão mostra o comando com botões *Permitir / Negar / Terminal*; os perigosos ganham borda vermelha. Seu clique responde o prompt de verdade.
- **Sempre permitir** — um quarto botão mostra a regra exata que vai criar (ex. `Bash(git *)`) e grava no seu `permissions.allow` (com backup) — treine sua allowlist clicando no caranguejo.
- **Perguntas também** — o Claude (ou qualquer script) faz perguntas de múltipla escolha ou texto livre pelo balão; responda por clique ou teclas 1/2/3, Esc pro terminal. Sem resposta a tempo → o prompt normal do terminal, sempre.
- **Uma ninhada de subagentes** — cada subagente nasce como um mini-caranguejo abaixo do Craby: o ovo racha, as patinhas tamborilam, depois ele se aposenta de bengala e some num puf. Sucesso e falha soam diferente — dá pra distinguir de ouvido.
- **Você sempre sabe quem chama** — uma legenda persistente nomeia o chamador ("ci: build falhou"); clicar no caranguejo abre a URL do chamador ou ergue a janela do projeto que precisa de você.
- **Sons e toasts** — toques discretos pra terminou/atenção/nascimento/puf, um bom-dia e um resumo local de uma linha do que cada sessão acabou de terminar.
- **Ele é vivo** — os olhos seguem seu mouse, manias espontâneas no ócio (um aceninho, um passinho de lado, uma bolhinha), gota de suor em tarefa longa. Troque de Space e ele se materializa na nova saindo de uma nuvenzinha mágica — *puf*.
- **Placar multi-sessão** — várias sessões? Ele mostra o estado de maior prioridade, pontinhos brancos pra sessões trabalhando em paralelo e o status por projeto no tooltip.
- **Gêmeo na menu bar** — um mini-caranguejo animado na barra, sempre em sincronia; recolha o flutuante pra barra quando quiser tela limpa. O menu mostra as estatísticas do dia e os últimos eventos.
- **Preferências** (menu → Preferências, ⌘,) — tópico ntfy, sons liga/desliga, tema de sons, esconder ao compartilhar tela. Atualização em um clique pelo mesmo menu quando sai versão nova.
- **Nunca no caminho** — flutua acima de tudo em todos os Spaces (até tela cheia), não rouba foco, sem ícone no Dock; arraste pra onde quiser. Interface em português, inglês e espanhol.

Cada bullet acima tem letra miúda na [referência](#referência).

## Ligue mais coisas

Cada uma destas fica a um clique ou um arquivo de distância:

**Vigiar o CI do GitHub** — menu da barra → 🧩 Addons → ligue o *github-watch* (precisa do `gh` autenticado). Depois abra a pasta do addon (🧩 Addons → abrir pasta) e liste os repositórios no `repos.txt`, um `owner/repo` por linha. Run que falha levanta atenção; clicar no caranguejo abre o run.

**Vigiar portas, PIDs e containers** — ligue o *live-watch* e edite o `targets.txt` dele: `port 4600 financas`, `pid 1234 worker`, `container meu-app`. Alvos vivos aparecem 🟢 no menu; um morto levanta atenção.

**Festa a cada git push** — copie o [`examples/git-hooks/pre-push`](examples/git-hooks/pre-push) pra `.git/hooks/` (o cabeçalho do arquivo mostra como ligar pra todos os repositórios de uma vez). Confete a cada push.

**Uso do plano de relance** — rode `claude setup-token` e cole a saída em `~/Library/Application Support/Craby/oauth-token`. O Craby mostra as janelas da assinatura (5h/semana) no tooltip e no menu, e ganha uma gota de suor preocupada acima de 80%. (Também lê de `CLAUDE_CODE_OAUTH_TOKEN`, `~/.claude/.credentials.json` ou do Keychain; sem token, sem o recurso — em silêncio.)

**Aviso no celular quando você está longe** — configure um tópico secreto do [ntfy](https://ntfy.sh) nas Preferências e assine o mesmo tópico no app do ntfy. Se ninguém mexe no Mac há 2 minutos e algo precisa de você, seu celular apita.

**Deixe o Claude preferir o balão** — adicione um snippet ao seu `~/.claude/CLAUDE.md` e o Claude faz perguntas rápidas pelo caranguejo em vez do terminal:

<details>
<summary>O snippet</summary>

```markdown
## Perguntas via Crab Companion
Para perguntas curtas de múltipla escolha, antes de usar AskUserQuestion, tente:
curl -s --max-time 50 -X POST -H 'Content-Type: application/json' \
  -d '{"title":"[<projeto>] Claude tem uma pergunta","detail":"<pergunta>","urgent":false,"options":["A","B"]}' \
  http://localhost:4923/ask
Resposta `opt:N` = opção de índice N; `txt:<texto>` = resposta digitada (use `"input":true` no lugar de options);
`ask`/vazio = use AskUserQuestion normalmente.
```

</details>

## Crie seu próprio addon

Um addon é uma pasta em `~/Library/Application Support/Craby/addons/<nome>/` com duas coisas: um manifesto `addon.json` e um executável. O Craby supervisiona — roda o executável a cada `interval` segundos com `CRABY_PORT` e `CRABY_SOURCE` no ambiente (nunca o token secreto); o executável faz uma rodada de checagem, reporta via [`/event` ou `/watch`](#api-http), e sai. A semente *github-watch*, que vem de fábrica, é um exemplo real e completo:

```json
{
  "name": "github-watch",
  "description": "CI do GitHub no pet (gh)",
  "exec": "run.sh",
  "source": "ci",
  "interval": 30,
  "scene": "atento",
  "props": { "garra": ["CW.", "CCG", "..G"] }
}
```

`scene` + `props` são o **figurino** do addon: enquanto a fonte dele está por cima, o pet interpreta aquela cena vestindo aqueles props. Um figurino de cada vez, inteiro — props de fontes diferentes nunca se misturam (o [`sourcePriority`](#configjson) decide quem está por cima; `claude` sempre vence enquanto trabalha).

Sem escrever grades na mão: o **construtor visual** — no [site](https://duperez.github.io/crab-companion/) ou no playground local em `http://localhost:4923` — deixa você escolher a cena, pintar os props célula a célula em cada slot e copiar o `addon.json` pronto. Contrato completo: [PROTOCOL.md](PROTOCOL.md).

## Referência

### API HTTP

Qualquer coisa na sua máquina pode conversar com o caranguejo em `http://localhost:4923` (contrato completo no [PROTOCOL.md](PROTOCOL.md)):

| Endpoint | O que faz |
|---|---|
| `GET /event?source=ci&session=id&state=working\|done\|attention\|idle` | evento estruturado multi-fonte; opcionais `project`, `detail`, `url` (clicar no pet abre) |
| `GET /watch?id=...&label=...&status=alive\|dead\|gone` | vigília de coisas vivas de longa duração — alive é batimento, dead levanta atenção, gone remove |
| `GET /working?session=id&project=nome` | atalho legado de estado (= `/event` com `source=claude`); também `/done`, `/attention`, `/idle` |
| `POST /ask` `{"title","detail","urgent"}` | balão de permissão (Permitir/Negar/Terminal), long-poll até o clique |
| `POST /ask` `{...,"options":["A","B"]}` | balão de múltipla escolha → responde `opt:0`, `opt:1`… |
| `POST /ask` `{...,"input":true}` | balão de texto livre → responde `txt:<texto digitado>` |
| `GET /celebrate?text=...` | confete + toast (ex.: de um hook `pre-push` do git) |
| `GET /scenes` | catálogo JSON de cenas, slots e paleta (o que o construtor de addons usa) |
| `GET /status` | JSON com versão, estado exibido, estados por sessão, watches e subagentes |
| `GET /subagent-start\|subagent-stop?session=id[&failed=1]` | nasce / aposenta um filhote manualmente |
| `GET /answer/<allow\|deny\|ask\|opt:N\|txt:...>` | responde o balão atual programaticamente (**exige token**) |
| `GET /quit` | encerra o app (**exige token**) |

Respostas do balão: `ask` significa "o usuário prefere o terminal" — trate isso (e erros de conexão) sempre como "volte pro fluxo normal".

Os dois endpoints que injetam decisões exigem um segredo, pra que nenhum processo local aleatório aprove coisas por você: passe `?token=$(cat "$HOME/Library/Application Support/Craby/token")` ou o header `X-Craby-Token`. O token é criado no primeiro uso, legível só pelo seu usuário. Addons nunca o recebem.

### CLI `craby`

Toda a API num comando amigável, instalado no seu PATH:

| Comando | O que faz |
|---|---|
| `craby status` | estado atual (JSON) |
| `craby working\|done\|attention\|idle` | marca estado (projeto = pasta atual) |
| `craby ask "pergunta" "A" "B"` | múltipla escolha no balão (imprime a escolhida) |
| `craby input "pergunta"` | texto livre no balão (imprime a resposta) |
| `craby answer <allow\|deny\|ask\|opt:N\|txt:...>` | responde o balão atual |
| `craby celebrate ["texto"]` | confete + toast |
| `craby event <fonte> <estado> [detalhe] [url]` | evento estruturado |
| `craby watch <id> <alive\|dead\|gone> [label] [url]` | vigília |
| `craby quit` | encerra o app |

### `config.json`

Tudo opcional, em `~/Library/Application Support/Craby/config.json` (a janela de Preferências edita por você):

| Chave | Padrão | O que faz |
|---|---|---|
| `ntfyTopic` | — | tópico do [ntfy](https://ntfy.sh) pra avisos no celular quando você está longe |
| `soundTheme` | `"classic"` | `classic` \| `soft` \| `retro` |
| `soundPack` | — | override de som por evento, ex. `{"done": "Hero"}` (eventos: `done`, `attention`, `hatch`, `poofOk`, `poofFail`) |
| `hideOnScreenShare` | `true` | esconder enquanto sua tela está sendo compartilhada (melhor esforço) |
| `sourcePriority` | `["ci", "docker"]` | qual fonte de addon veste o pet quando várias estão ativas; `claude` sempre vem primeiro enquanto trabalha |

Na mesma pasta: `sprites.json` troca o visual do Craby inteiro (grades de caracteres por estado mais uma paleta; estados omitidos mantêm a arte padrão, grades inválidas são ignoradas) e `stats.json` é a memória dele (tarefas, tempo, eventos — apague pra começar do zero).

### Hooks do Claude Code

O `setup.sh` registra estes no `~/.claude/settings.json` (com backup antes; seus hooks existentes nos mesmos eventos nunca são sobrescritos):

| Evento do hook | Reação do caranguejo |
|---|---|
| `UserPromptSubmit` | senta no laptop e digita |
| `PostToolUse` | batimento cardíaco — mantém o "trabalhando" vivo (sessão morta vira ociosa após 10 min sem um) |
| `SubagentStart` / `SubagentStop` | um filhote nasce abaixo do Craby / se aposenta de bengala e dá puf |
| `Stop` | comemora (terminou) |
| `Notification` | acena pedindo atenção |
| `PermissionRequest` | abre o balão de decisão e **espera seu clique** |

O fluxo do `PermissionRequest` é o mais legal: o hook segura a conexão aberta (long-poll) enquanto o balão está na tela. Seu clique volta como stdout do hook — uma decisão de permissão oficial — e o prompt do terminal nem chega a aparecer. Sem resposta em ~45 s? O hook não devolve nada e o prompt normal aparece. O caranguejo nunca aprova nada sozinho.

### Build e testes

AppKit puro, sem dependências — tudo em [`Sources/`](Sources/) (mapa de módulos e as entranhas do motor no [docs/DESIGN.md](docs/DESIGN.md)):

```bash
swiftc Sources/*.swift -o pet && ./pet     # rodar avulso
curl localhost:4923/working                # cutucar estados
open http://localhost:4923                 # playground: todos os endpoints + construtor de addons
swiftc Sources/Sprites.swift Sources/Scenes.swift Sources/HTTPServer.swift \
  Sources/L10n.swift Sources/Sounds.swift Sources/Stats.swift \
  Sources/PlanUsage.swift Tests/main.swift -o run_tests && ./run_tests
./install.sh                               # levar a mudança pro app instalado
```

O CI roda build, testes e shellcheck a cada push; uma tag `v*` compila o binário universal e publica o release automaticamente.

---

**Funciona com qualquer agente** — os hooks são só um cliente; qualquer coisa que rode `curl` pode controlar o Craby (Codex CLI, Gemini CLI, cron, builds longos). A integração mais simples é o [`examples/craby-run`](examples/craby-run): `cp examples/craby-run /usr/local/bin/` e depois `craby-run npm run build` — trabalhando enquanto roda, confete no sucesso, atenção na falha.

Curioso pra saber como o projeto funciona por dentro — o motor de cenas, o supervisor de addons, as regras de design e o porquê delas? Leia o [docs/DESIGN.md](docs/DESIGN.md) (em inglês). Issues e PRs são bem-vindos.

[MIT](LICENSE) — feito com [Claude Code](https://claude.com/claude-code), claro. 🦀
