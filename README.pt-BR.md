# 🦀 Crab Companion

> Conheça o **Craby** — um caranguejinho em pixel art que vive por cima da tela do seu Mac e observa o seu workflow de desenvolvimento. Sessões do Claude Code, runs de CI, servidores de dev, containers: qualquer coisa acontecendo na sua máquina pode aparecer na cara dele — e quando algo precisa de você, você responde direto pelo balão de fala.

*Read in [English](README.md) · Site: [duperez.github.io/crab-companion](https://duperez.github.io/crab-companion/)*

<p align="center">
  <img src="docs/demo.gif" width="140" alt="Craby passando pelas cenas: ocioso, trabalhando no laptop, comemorando e pedindo atenção">
</p>

O Craby é uma **interface de presença**: um pet de desktop que qualquer "cérebro" local pode usar como rosto. O Claude Code é a integração-bandeira — mas o [protocolo HTTP](PROTOCOL.md) é aberto, e qualquer coisa que rode `curl` pode controlá-lo. Ele resolve o problema do "já terminou?" ficando sempre no canto do seu olho:

- 😴 **Ocioso** — garras pro alto, tamborilando devagar, piscando de vez em quando (e se tudo ficar quieto por 10 minutos, ele deita e dorme — Zzz)
- 💻 **Trabalhando** — debruçado num laptopzinho, mãos martelando o teclado
- 🔍 **De vigília** — de pé, atento, com uma lupa ou um caixote, vigiando algo vivo (um pipeline de CI, um servidor de dev, um container)
- 🎉 **Terminou** — pinças pro alto, confete (com um *plim* opcional)
- ❗ **Precisa de você** — acenando com um "!" piscando (com um *ping* opcional), e uma legendinha dizendo exatamente quem está chamando

E o melhor: quando o Claude pede permissão ou tem uma pergunta, um **balão de fala** abre embaixo do Craby e você responde ali mesmo.

## O que ele faz

- **Observa o workflow inteiro, não só uma ferramenta** — um [protocolo](PROTOCOL.md) aberto permite que qualquer processo local se reporte: `/event` estruturado e multi-fonte com source/session/state/project/detail/url, `/watch` para vigiar coisas vivas de longa duração (alive/dead/gone), `/celebrate` para confete, `/ask` para balões de pergunta. O Claude Code é um cliente entre vários — o cliente-bandeira.
- **🧩 Addons** — ensine o Craby a vigiar coisas novas soltando uma pasta com um `addon.json` e um executável em `~/Library/Application Support/Craby/addons/`. O Craby é o supervisor: roda seu executável no intervalo declarado, mata execuções penduradas depois de 60 s e entrega `CRABY_PORT`/`CRABY_SOURCE` (nunca o token secreto). O manifesto declara a fonte, o intervalo, a cena e o *figurino* do addon — props desenhados em JSON. Dois addons vêm de fábrica como **sementes**, copiadas pra sua pasta como exemplos editáveis: **github-watch** (runs de CI via `gh`, um repositório por linha no `repos.txt`) e **live-watch** (portas, PIDs e containers listados no `targets.txt`). Ligue e desligue cada um pelo menu da barra, em 🧩 Addons.
- **Construtor visual de addons** — abra `http://localhost:4923` no navegador: o playground servido pelo próprio app tem botões pra testar todos os endpoints, mais um construtor onde você escolhe a cena, pinta os props célula a célula em cada slot e recebe o `addon.json` gerado, pronto pra salvar.
- **Um figurino de cada vez** — a fonte ativa de maior prioridade (`sourcePriority` na config; `claude` sempre vence enquanto trabalha) veste o pet com sua cena e seus props. Props de fontes diferentes nunca se misturam — o Craby veste um figurino inteiro.
- **Um caranguejo redesenhado com motor de cenas de verdade** — arte v3: olhos em talo, corpo em domo, garras que parecem mãos, 84 px na tela. Cenas são poses do corpo (ocioso, debruçado no laptop — desenhado *atrás* das mãos que digitam, de vigília, comemorando com as pinças pro alto, deitado dormindo, acenando por atenção); props são grades pequenas ancoradas em slots nomeados, com camada frente/trás e âncora por quadro.
- **Gêmeo na menu bar** — um mini-caranguejo animado na barra superior, sempre em sincronia. Recolha o flutuante pra barra quando precisar de tela limpa (menu "Recolher para a barra").
- **Permissões pelo balão** — quando o Claude Code pede permissão, o balão mostra o que ele quer rodar com botões *Permitir / Negar / Terminal*. Seu clique responde o prompt de verdade, via o hook oficial `PermissionRequest`. Comandos perigosos (`rm`, `push --force`, `sudo`…) ganham borda vermelha. Um quarto botão, **Sempre permitir**, mostra a regra exata que vai criar (ex. `Bash(git *)`) e grava no seu `permissions.allow` do `~/.claude/settings.json` (com backup `.craby-bak`) — treine sua allowlist clicando no caranguejo.
- **Uso do plano de relance** — se houver um token OAuth do Claude Code disponível, o Craby mostra as janelas da sua assinatura (% da sessão de 5h, % da semana) no tooltip e no menu, e ganha uma gota de suor preocupada quando a janela de 5h passa de 80%. Sem token? O recurso some em silêncio. Busca do token: env `CLAUDE_CODE_OAUTH_TOKEN` → `~/.claude/.credentials.json` → `~/Library/Application Support/Craby/oauth-token` (cole ali a saída do `claude setup-token`) → Keychain do macOS.
- **Comemora seus pushes** — `GET /celebrate` (ou `craby celebrate "texto"`) solta confete e um toast. Instale como hook do git com o [`examples/git-hooks/pre-push`](examples/git-hooks/pre-push) e o Craby festeja a cada `git push`.
- **Perguntas pelo balão** — a API HTTP local permite que o Claude (ou qualquer script) faça perguntas de múltipla escolha ou texto livre pelo balão, com fallback pro terminal.
- **Você sempre sabe quem chama** — enquanto uma atenção está pendente, uma legenda persistente perto do pet nomeia quem está chamando ("ci: build falhou"), e clicar no caranguejo abre a URL do chamador (o run de CI, o PR…) ou ergue a janela do projeto que precisa de você (requer permissão de Acessibilidade).
- **Placar multi-sessão** — várias sessões ao mesmo tempo? O caranguejo mostra o estado de maior prioridade entre todas, com pontinhos brancos para sessões trabalhando em paralelo e um tooltip listando o status de cada projeto.
- **Uma ninhada de subagentes** — quando o Claude Code dispara subagentes, cada um nasce como um mini-caranguejo numa faixa abaixo do Craby: um ovo racha com um *pop*, as patinhas tamborilam enquanto o subagente roda, e quando ele termina o filhote se aposenta de bengala por uns segundos e some num puf de estrelinhas (*tink*). Subagente que falha ou fica órfão dá um puf cinza/vermelho com um som grave (*basso*) — dá pra distinguir sucesso de falha só de ouvido. Até 5 filhotes visíveis, contagem por sessão no tooltip do Craby ("· N 🐣"), reportado no `GET /status`, alimentado pelos hooks oficiais `SubagentStart`/`SubagentStop`. Até onde sabemos, nenhum outro pet de status de código transforma seus subagentes em filhotes.
- **Sons com temas** — toques discretos pra terminou/atenção/nascimento/puf, em três temas (Clássico, Suave, Retrô) e com override por evento. Terminou e atenção tocam por sessão concluída, de qualquer fonte. Liga/desliga e escolhe o tema nas Preferências.
- **Craby fala** — mini-toasts acima da cabeça dele: bom-dia, marcos de tarefas, recordes de ninhada e um resumo de uma linha do que cada sessão acabou de terminar (extraído localmente do transcript — nada sai da sua máquina).
- **Janela de Preferências** — tópico ntfy, sons, tema de sons, recolher ao compartilhar tela e mais, sem editar arquivo de configuração (menu → Preferências).
- **CLI `craby`** — `craby status`, `craby ask "pergunta" A B`, `craby input "pergunta"`, `craby done`… toda a API HTTP num comando amigável, instalado no seu PATH.
- **Atualização em um clique** — quando sai versão nova, o menu oferece "Atualizar agora": o Craby baixa o release, se troca e reinicia.
- **Modo apresentação** — some sozinho enquanto sua tela está sendo compartilhada (melhor esforço; configurável nas Preferências).
- **Ele é vivo** — os olhos dele seguem seu mouse pela tela, ele tem manias espontâneas no ócio (um aceninho, um passinho de lado, uma bolhinha), gota de esforço quando a tarefa demora, soneca quando nada acontece. Troque de Space e ele vai embora deslizando com a tela antiga, e se materializa na nova saindo de uma nuvenzinha mágica — *puf*. No primeiro uso, ele se apresenta.
- **Estatísticas do dia** — o menu da barra mostra o dia (tarefas concluídas, projetos, tempo trabalhado) e os últimos eventos — clique num deles pra pular pra janela daquele projeto.
- **Aviso no celular quando você está longe** — opcional: se ninguém mexe no Mac há 2 minutos e algo precisa de você, o Craby avisa seu celular via [ntfy](https://ntfy.sh) (veja Configuração).
- **Sempre visível, nunca no caminho** — flutua acima de todos os apps, em todos os Spaces, até sobre apps em tela cheia. Nunca rouba o foco, sem ícone no Dock, invisível ao cmd-tab. Arraste pra onde quiser; a posição fica salva. Atalhos no balão também: clique nele e aperte 1/2/3 pra escolher ou Esc pro terminal.
- **Português, inglês e espanhol** — a interface segue o idioma do sistema.
- **Seguro por padrão** — se você não responder um balão a tempo, tudo cai no prompt normal do terminal. O Craby nunca decide nada sozinho, addons nunca veem o token secreto, e os endpoints que *injetam decisões* o exigem.

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

Todos os caminhos terminam igual: o app em `Applications/Craby.app` (zero dependências), um LaunchAgent iniciando no login e os hooks do Claude Code no `~/.claude/settings.json` — sua configuração anterior ganha backup, e hooks existentes nos mesmos eventos nunca são sobrescritos. Reinicie as sessões abertas do Claude Code e pronto. Pra remover tudo: `./uninstall.sh`.

## Como funciona

```
Claude Code ──── hooks ──┐
CI / servidores  addons ─┼──> localhost:4923 ──> 🦀 (janela flutuante + menu bar)
qualquer coisa ── curl ──┘         ^                │
                                   └── decisão (long-poll HTTP) ──┘
```

Tudo fala o mesmo [protocolo](PROTOCOL.md) aberto com o servidor HTTP local do caranguejo. O Claude Code entra via [hooks](https://code.claude.com/docs/en/hooks) em eventos do ciclo de vida — cada hook é um script minúsculo que faz POST pro Craby:

| Evento do hook | Reação do caranguejo |
|---|---|
| `UserPromptSubmit` | senta no laptop e digita |
| `PostToolUse` | batimento cardíaco — mantém o "trabalhando" vivo (sessão morta vira ociosa após 10 min sem um) |
| `SubagentStart` / `SubagentStop` | um filhote nasce abaixo do Craby / se aposenta de bengala e dá puf |
| `Stop` | comemora (terminou) |
| `Notification` | acena pedindo atenção |
| `PermissionRequest` | abre o balão de decisão e **espera seu clique** |

O fluxo do `PermissionRequest` é o mais legal: o hook segura a conexão aberta (long-poll) enquanto o balão está na tela. Seu clique volta como stdout do hook — uma decisão de permissão oficial — e o prompt do terminal nem chega a aparecer. Sem resposta em ~45 s? O hook não devolve nada e o prompt normal aparece. O caranguejo nunca aprova nada sozinho.

## API HTTP

Qualquer coisa na sua máquina pode conversar com o caranguejo (contrato completo no [PROTOCOL.md](PROTOCOL.md)):

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
| `GET /answer/<allow\|deny\|ask\|opt:N\|txt:...>` | responde o balão atual programaticamente (**exige token**) |
| `GET /quit` | encerra o app (**exige token**) |

Respostas do balão: `ask` significa "o usuário prefere o terminal" — trate isso (e erros de conexão) sempre como "volte pro fluxo normal".

Os dois endpoints que injetam decisões exigem um segredo, pra que nenhum processo local aleatório aprove coisas por você: passe `?token=$(cat "$HOME/Library/Application Support/Craby/token")` (ou o header `X-Craby-Token`). O token é criado no primeiro uso, legível só pelo seu usuário. Addons nunca o recebem.

## Addons

Um addon é uma pasta em `~/Library/Application Support/Craby/addons/<nome>/` com duas coisas: um manifesto `addon.json` e um executável. O Craby supervisiona — roda o executável a cada `interval` segundos, vigia execuções penduradas e entrega `CRABY_PORT` e `CRABY_SOURCE` no ambiente. O executável faz uma rodada de checagem (consulta o `gh`, sonda uma porta, `docker ps`…), reporta via `/event` e `/watch`, e sai.

O manifesto também declara o **figurino** do addon: qual cena o Craby interpreta enquanto essa fonte está por cima, e os props a carimbar nos slots da cena — desenhados direto no JSON:

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

As duas sementes de fábrica (**github-watch** e **live-watch**) são copiadas pra sua pasta de addons na primeira execução como exemplos editáveis — abra, mexa, quebre, são suas. Gerencie tudo pelo menu da barra: 🧩 Addons → liga/desliga cada um, abrir a pasta.

Não quer escrever grades na mão? O playground em `http://localhost:4923` tem um **construtor visual**: escolha a cena, pinte os props célula a célula em todos os slots e copie o `addon.json` gerado.

## Configuração

Tudo opcional, tudo em `~/Library/Application Support/Craby/`:

- `config.json` — `{"ntfyTopic": "seu-topico-secreto"}` pra avisos no celular quando você está longe (assine o mesmo tópico no [app do ntfy](https://ntfy.sh)); `{"sourcePriority": ["ci", "docker"]}` pra decidir qual fonte de addon veste o pet quando várias estão ativas (`claude` sempre vem primeiro enquanto trabalha).
- `sprites.json` — troque o visual do Craby inteiro: grades de caracteres por estado mais uma paleta. Estados omitidos mantêm a arte padrão; grades inválidas são ignoradas.
- `stats.json` — a memória do Craby (tarefas, tempo, eventos). Apague pra começar do zero.

## Funciona com qualquer agente

Os hooks do Claude Code são só um cliente — o protocolo HTTP é agnóstico. Qualquer coisa que rode `curl` pode controlar o Craby: Codex CLI, Gemini CLI, cron, scripts de CI, builds longos. A integração mais simples é o [`examples/craby-run`](examples/craby-run), um wrapper que marca a sessão como trabalhando, roda seu comando e comemora (ou pede atenção se falhar):

```bash
cp examples/craby-run /usr/local/bin/
craby-run npm run build
craby-run codex exec "refatore os testes"
```

Pra integrações mais profundas, escreva um addon (veja acima) ou use os endpoints diretamente — veja o [PROTOCOL.md](PROTOCOL.md).

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

AppKit puro, sem dependências, em módulos pequenos dentro de [`Sources/`](Sources/): `Scenes.swift` (motor de cenas/props/slots), `Sprites.swift` (pixel art), `Addons.swift` (o supervisor), `Playground.swift` (a página servida pelo app), `HTTPServer.swift`, `PlanUsage.swift`, `Stats.swift`, `Sounds.swift`, `L10n.swift`, `App.swift`. Cenas e props são grades de caracteres — editar o Craby é literalmente editar texto:

```
"....W..W....",
"...WBWWBW...",      R corpo   W/B olhos em talo
"..RRRRRRRR..",      D sombra  Y efeitos
".RRRRRRRRRR.",      props são carimbados em slots
"RRRRRRRRRRRR",      ("garra", "mesa", "chao", "ceu"…)
```

Uma cena é uma pose do corpo (quadros completos) mais slots nomeados; um prop é uma grade pequena ancorada num slot, desenhada na frente ou atrás do corpo, com âncora por quadro. O laptop da cena de trabalho é ele próprio um prop — desenhado atrás das mãos que digitam.

Ciclo de dev:

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

## Licença

[MIT](LICENSE) — feito com [Claude Code](https://claude.com/claude-code), claro. 🦀
