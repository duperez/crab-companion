# 🦀 Crab Companion

<p align="center">
  <img src="docs/demo.gif" width="140" alt="Craby cycling through his scenes: idle, working on his laptop, celebrating, and asking for attention">
</p>

**Craby** is a tiny pixel-art crab that lives on top of your Mac screen and watches your development workflow. He is a **presence interface**: a desktop pet any local "brain" can use as its face — Claude Code is the flagship integration, and the [protocol](PROTOCOL.md) is open, so anything that can `curl` can drive him. He solves the "is it done yet?" problem by living in the corner of your eye:

- 😴 **Idle** — claws up, tapping slowly; ten quiet minutes and he lies down to sleep
- 💻 **Working** — hunched over a tiny laptop, hammering the keyboard
- 🔍 **On watch** — standing at attention, keeping vigil over something alive (CI, a server, a container)
- 🎉 **Done** — pincers to the sky, confetti
- ❗ **Needs you** — waving with a blinking "!", plus a caption naming exactly who's calling

Website: [duperez.github.io/crab-companion](https://duperez.github.io/crab-companion/) · Leia em [Português](README.pt-BR.md)

## Install

```bash
brew tap duperez/craby
brew install --cask craby
"/Applications/Craby.app/Contents/Resources/setup.sh"   # connects Craby to Claude Code
```

Requirements: macOS 13+, `jq` (`brew install jq`) and [Claude Code](https://claude.com/claude-code). Restart any open Claude Code sessions and you're done. To remove everything: `./uninstall.sh`.

<details>
<summary>Other ways to install</summary>

**From source** (also needs Xcode Command Line Tools, `xcode-select --install`):

```bash
git clone https://github.com/duperez/crab-companion.git
cd crab-companion
./install.sh
```

**Prebuilt app** — grab `Craby.app.zip` from [Releases](https://github.com/duperez/crab-companion/releases), unzip into `/Applications`, run `xattr -dr com.apple.quarantine /Applications/Craby.app` (the app isn't code-signed), then run `setup.sh` inside `Craby.app/Contents/Resources/`.

Every path ends the same way: the app lands in `Applications/Craby.app` (zero dependencies), a LaunchAgent starts it at login, and the Claude Code hooks are added to `~/.claude/settings.json` — your previous config is backed up, and existing hooks on the same events are never overwritten.

</details>

## Out of the box

Install him and all of this is already on — zero configuration:

- **States follow your sessions** — the Claude Code [hooks](#claude-code-hooks) drive him: typing when you prompt, celebrating on finish, waving when something needs you.
- **Permissions from the bubble** — when Claude asks for permission, the bubble shows the command with *Allow / Deny / Terminal* buttons; dangerous ones get a red border. Your click answers the real prompt.
- **Always allow** — a fourth button shows the exact rule it will create (e.g. `Bash(git *)`) and writes it to your `permissions.allow` (with backup) — train your allowlist by clicking the crab.
- **Questions too** — Claude (or any script) can ask multiple-choice or free-text questions through the bubble; answer by click or keys 1/2/3, Esc for the terminal. No answer in time → the normal terminal prompt, always.
- **A brood of subagents** — each subagent hatches as a baby crab below Craby: the egg pops, tiny legs drum, then it retires with a cane and poofs. Success and failure sound different — you can tell by ear.
- **You always know who's calling** — a persistent caption names the caller ("ci: build failed"); clicking the crab opens the caller's URL or raises the window of the project that needs you.
- **Sounds & toasts** — subtle cues for done/attention/hatch/poof, a good-morning greeting, and a one-line local summary of what each session just finished.
- **He's alive** — eyes follow your mouse, spontaneous idle quirks (a wave, a side-step, a bubble), a sweat drop on long tasks. Switch Spaces and he materializes on the new one out of a little magic cloud — *poof*.
- **Multi-session scoreboard** — several sessions? He shows the highest-priority state, white dots for parallel working sessions, and per-project status in the tooltip.
- **Menu bar twin** — a mini animated crab in the menu bar, always in sync; collapse the floating one into the bar for a clean screen. Its menu shows today's stats and recent events.
- **Preferences** (menu → Preferences, ⌘,) — ntfy topic, sounds on/off, sound theme, hide-on-screen-share. One-click updates from the same menu when a new version is out.
- **Never in the way** — floats above everything on every Space (even fullscreen), steals no focus, no Dock icon; drag him anywhere. UI in English, Portuguese and Spanish.

Every bullet above has fine print in the [reference](#reference).

## Turn on more

Each of these is one click or one file away:

**Watch GitHub CI** — menu bar → 🧩 Addons → enable *github-watch* (needs `gh` authenticated). Then open the addon folder (🧩 Addons → open folder) and list repos in `repos.txt`, one `owner/repo` per line. Failed runs raise attention; clicking the crab opens the run.

**Watch ports, PIDs and containers** — enable *live-watch* and edit its `targets.txt`: `port 4600 finances`, `pid 1234 worker`, `container my-app`. Live targets show 🟢 in the menu; a dead one raises attention.

**Party on every git push** — copy [`examples/git-hooks/pre-push`](examples/git-hooks/pre-push) into `.git/hooks/` (the file's header shows how to enable it for all repos at once). Confetti on every push.

**Plan usage at a glance** — run `claude setup-token` and paste the output into `~/Library/Application Support/Craby/oauth-token`. Craby shows your 5h/weekly subscription windows in the tooltip and menu, and gets a worried sweat drop past 80%. (Also read from `CLAUDE_CODE_OAUTH_TOKEN`, `~/.claude/.credentials.json` or the Keychain; no token, no feature — silently.)

**Phone alerts when you're away** — set a secret [ntfy](https://ntfy.sh) topic in Preferences and subscribe to it in the ntfy app. If nobody touches the Mac for 2 minutes and something needs you, your phone pings.

**Let Claude prefer the bubble** — add a snippet to `~/.claude/CLAUDE.md` and Claude asks quick questions through the crab instead of the terminal:

<details>
<summary>The snippet</summary>

```markdown
## Questions via Crab Companion
For short multiple-choice questions, before using AskUserQuestion, try:
curl -s --max-time 50 -X POST -H 'Content-Type: application/json' \
  -d '{"title":"[<project>] Claude has a question","detail":"<question>","urgent":false,"options":["A","B"]}' \
  http://localhost:4923/ask
Response `opt:N` = option index N; `txt:<text>` = typed answer (use `"input":true` instead of options);
`ask`/empty = fall back to AskUserQuestion.
```

</details>

## Build your own addon

An addon is a folder in `~/Library/Application Support/Craby/addons/<name>/` with two things: an `addon.json` manifest and an executable. Craby supervises it — runs the executable every `interval` seconds with `CRABY_PORT` and `CRABY_SOURCE` in the environment (never the secret token); the executable does one round of checking, reports via [`/event` or `/watch`](#http-api), and exits. The bundled *github-watch* seed is a complete real example:

```json
{
  "name": "github-watch",
  "description": "GitHub CI on the pet (gh)",
  "exec": "run.sh",
  "source": "ci",
  "interval": 30,
  "scene": "atento",
  "props": { "garra": ["CW.", "CCG", "..G"] }
}
```

`scene` + `props` are the addon's **costume**: while its source is on top, the pet performs that scene wearing those props. One costume at a time, whole — props from different sources never mix ([`sourcePriority`](#configjson) decides who's on top; `claude` always wins while working).

No hand-writing grids: the **visual builder** — on the [website](https://duperez.github.io/crab-companion/) or in the local playground at `http://localhost:4923` — lets you pick a scene, paint props cell by cell in each slot, and copy the finished `addon.json`. Full contract: [PROTOCOL.md](PROTOCOL.md).

## Reference

### HTTP API

Anything on your machine can talk to the crab at `http://localhost:4923` (full contract in [PROTOCOL.md](PROTOCOL.md)):

| Endpoint | What it does |
|---|---|
| `GET /event?source=ci&session=id&state=working\|done\|attention\|idle` | structured multi-source event; optional `project`, `detail`, `url` (clicking the pet opens it) |
| `GET /watch?id=...&label=...&status=alive\|dead\|gone` | vigil over long-lived things — alive heartbeats, dead raises attention, gone removes |
| `GET /working?session=id&project=name` | legacy state shortcut (= `/event` with `source=claude`); also `/done`, `/attention`, `/idle` |
| `POST /ask` `{"title","detail","urgent"}` | permission bubble (Allow/Deny/Terminal), long-polls until click |
| `POST /ask` `{...,"options":["A","B"]}` | multiple-choice bubble → answers `opt:0`, `opt:1`… |
| `POST /ask` `{...,"input":true}` | free-text bubble → answers `txt:<typed text>` |
| `GET /celebrate?text=...` | confetti + toast (e.g. from a git `pre-push` hook) |
| `GET /scenes` | JSON catalog of scenes, slots and palette (what the addon builder uses) |
| `GET /status` | JSON with version, displayed state, per-session states, watches and subagents |
| `GET /subagent-start\|subagent-stop?session=id[&failed=1]` | hatch / retire a baby crab manually |
| `GET /answer/<allow\|deny\|ask\|opt:N\|txt:...>` | answer the current bubble programmatically (**token required**) |
| `GET /quit` | quit the app (**token required**) |

Bubble answers: `ask` means "user wants the terminal" — always treat it (and connection errors) as "fall back to the normal flow".

The two decision-injecting endpoints require a secret so no random local process can approve things on your behalf: pass `?token=$(cat "$HOME/Library/Application Support/Craby/token")` or the `X-Craby-Token` header. The token is created on first launch, readable only by your user. Addons never receive it.

### `craby` CLI

The whole API in a friendly wrapper, installed to your PATH:

| Command | What it does |
|---|---|
| `craby status` | current state (JSON) |
| `craby working\|done\|attention\|idle` | set a state (project = current folder) |
| `craby ask "question" "A" "B"` | multiple-choice bubble (prints the chosen option) |
| `craby input "question"` | free-text bubble (prints the typed answer) |
| `craby answer <allow\|deny\|ask\|opt:N\|txt:...>` | answer the current bubble |
| `craby celebrate ["text"]` | confetti + toast |
| `craby event <source> <state> [detail] [url]` | structured event |
| `craby watch <id> <alive\|dead\|gone> [label] [url]` | vigil |
| `craby quit` | quit the app |

### `config.json`

Everything optional, in `~/Library/Application Support/Craby/config.json` (the Preferences window edits it for you):

| Key | Default | What it does |
|---|---|---|
| `ntfyTopic` | — | [ntfy](https://ntfy.sh) topic for phone alerts when you're away |
| `soundTheme` | `"classic"` | `classic` \| `soft` \| `retro` |
| `soundPack` | — | per-event sound override, e.g. `{"done": "Hero"}` (events: `done`, `attention`, `hatch`, `poofOk`, `poofFail`) |
| `hideOnScreenShare` | `true` | hide while your screen is being shared (best effort) |
| `sourcePriority` | `["ci", "docker"]` | which addon source dresses the pet when several are active; `claude` always comes first while working |

Also in the same folder: `sprites.json` reskins Craby entirely (character grids per state plus a palette; omitted states keep the default art, invalid grids are ignored) and `stats.json` is his memory (tasks, time worked, events — delete it to start fresh).

### Claude Code hooks

`setup.sh` wires these into `~/.claude/settings.json` (backed up first; your existing hooks on the same events are never overwritten):

| Hook event | Crab reaction |
|---|---|
| `UserPromptSubmit` | starts typing on the laptop |
| `PostToolUse` | heartbeat — keeps "working" alive (dead sessions go idle after 10 min without one) |
| `SubagentStart` / `SubagentStop` | a baby crab hatches below Craby / retires with a cane and poofs |
| `Stop` | celebrates (done) |
| `Notification` | waves for attention |
| `PermissionRequest` | opens the decision bubble and **waits for your click** |

The `PermissionRequest` flow is the fun one: the hook holds its connection open (long-poll) while the bubble is on screen. Your click travels back as the hook's stdout — an official permission decision — so the terminal prompt never even appears. No answer in ~45 s? The hook returns nothing and the normal prompt shows up. The crab never auto-approves anything.

### Build & test

Plain AppKit, no dependencies — everything under [`Sources/`](Sources/) (module map and engine internals in [docs/DESIGN.md](docs/DESIGN.md)):

```bash
swiftc Sources/*.swift -o pet && ./pet     # run standalone
curl localhost:4923/working                # poke states
open http://localhost:4923                 # playground: every endpoint + addon builder
swiftc Sources/Sprites.swift Sources/Scenes.swift Sources/HTTPServer.swift \
  Sources/L10n.swift Sources/Sounds.swift Sources/Stats.swift \
  Sources/PlanUsage.swift Tests/main.swift -o run_tests && ./run_tests
./install.sh                               # ship your change into the installed app
```

CI runs the build, the tests and shellcheck on every push; tagging `v*` builds a universal binary and publishes the release automatically.

---

**Works with any agent** — the hooks are just one client; anything that can `curl` can drive Craby (Codex CLI, Gemini CLI, cron, long builds). The simplest integration is [`examples/craby-run`](examples/craby-run): `cp examples/craby-run /usr/local/bin/` then `craby-run npm run build` — working while it runs, confetti on success, attention on failure.

Curious how the project works inside — the scene engine, the addon supervisor, the design rules and why they exist? Read [docs/DESIGN.md](docs/DESIGN.md). Issues and PRs welcome.

[MIT](LICENSE) — built with [Claude Code](https://claude.com/claude-code), naturally. 🦀
