# 🦀 Crab Companion

> Conheça o **Craby** — um caranguejinho em pixel art que vive por cima da tela do seu Mac e te conta o que o Claude Code está fazendo. E deixa você responder sem tocar no terminal.

*Read in [English](README.md).*

<p align="center">
  <img src="docs/icon.png" width="160" alt="Craby, o caranguejo pixel art do Crab Companion">
</p>

Você manda o Claude Code trabalhar em algo demorado, troca de aplicativo e… e agora? Fica dando alt-tab pra conferir? O Craby resolve o problema do "já terminou?" ficando sempre no canto do seu olho:

- 😴 **Ocioso** — garras pro alto, tamborilando devagar, piscando de vez em quando
- 💻 **Trabalhando** — debruçado num laptopzinho, garras martelando o teclado, teclas voando
- 🎉 **Terminou** — pulando entre faíscas (com um *plim* opcional)
- ❗ **Precisa de você** — acenando com um "!" piscando (com um *ping* opcional)

E o melhor: quando o Claude pede permissão ou tem uma pergunta, um **balão de fala** abre embaixo do Craby e você responde ali mesmo.

## O que ele faz

- **Sempre visível, nunca no caminho** — flutua acima de todos os apps, em todos os Spaces, até sobre apps em tela cheia. Nunca rouba o foco, sem ícone no Dock, invisível ao cmd-tab.
- **Gêmeo na menu bar** — um mini-caranguejo animado na barra superior, sempre em sincronia. Recolha o flutuante pra barra quando precisar de tela limpa (menu "Recolher para a barra").
- **Permissões pelo balão** — quando o Claude Code pede permissão, o balão mostra o que ele quer rodar com botões *Permitir / Negar / Terminal*. Seu clique responde o prompt de verdade, via o hook oficial `PermissionRequest`. Comandos perigosos (`rm`, `push --force`, `sudo`…) ganham borda vermelha.
- **Perguntas pelo balão** — uma API HTTP local permite que o Claude (ou qualquer script) faça perguntas de múltipla escolha ou texto livre pelo balão, com fallback pro terminal.
- **Placar multi-sessão** — várias sessões do Claude Code ao mesmo tempo? O caranguejo mostra o estado de maior prioridade entre todas, com pontinhos brancos para sessões trabalhando em paralelo e um tooltip listando o status de cada projeto. Clicar nele ergue a janela do projeto que precisa de você (requer permissão de Acessibilidade).
- **Sons** — *plim* discreto no terminou, *ping* na atenção. Liga/desliga no menu da barra.
- **Seguro por padrão** — se você não responder um balão a tempo, tudo cai no prompt normal do terminal. O caranguejo nunca decide nada sozinho.

## Instalação

Requisitos: macOS 13+, [Xcode Command Line Tools](https://developer.apple.com/xcode/resources/) (`xcode-select --install`), `jq` (`brew install jq`) e [Claude Code](https://claude.com/claude-code).

```bash
git clone https://github.com/duperez/crab-companion.git
cd crab-companion
./install.sh
```

O instalador compila o app (~300 KB, zero dependências), instala em `~/Applications/Crab Companion.app`, registra um LaunchAgent pra iniciar no login e adiciona os hooks do Claude Code no `~/.claude/settings.json` (sua configuração anterior ganha backup, e hooks existentes nos mesmos eventos nunca são sobrescritos).

Reinicie as sessões do Claude Code abertas e pronto. Pra remover tudo: `./uninstall.sh`.

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
| `GET /answer/<allow\|deny\|ask\|opt:N\|txt:...>` | responde o balão atual programaticamente |
| `GET /quit` | encerra o app |

Respostas do balão: `ask` significa "o usuário prefere o terminal" — trate isso (e erros de conexão) sempre como "volte pro fluxo normal".

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

Tudo vive num arquivo só, o [`main.swift`](main.swift) (~700 linhas de AppKit, sem dependências). Os sprites são grades de caracteres — editar o caranguejo é literalmente editar texto:

```
".RR........RR.",
".RR........RR.",      R corpo   W/B olhos
"..R........R..",      D sombra  Y efeitos
"..RRRRRRRRRR..",      G/L laptop
".RRWBRRRRWBRR.",
```

Ciclo de dev: `swiftc main.swift -o pet && ./pet`, e `curl localhost:4923/working` pra cutucar os estados. Pra levar sua mudança pro app instalado, rode `./install.sh` de novo.

## Licença

[MIT](LICENSE) — feito com [Claude Code](https://claude.com/claude-code), claro. 🦀
