# 🦀 Crab Companion

> Meet **Craby** — a tiny pixel-art crab that lives on top of your Mac screen and watches your development workflow. Claude Code sessions, CI runs, dev servers, containers: anything happening on your machine can show up on his face — and when something needs you, you answer right from his speech bubble.

*Leia em [Português](README.pt-BR.md) · Website: [duperez.github.io/crab-companion](https://duperez.github.io/crab-companion/)*

<p align="center">
  <img src="docs/demo.gif" width="140" alt="Craby cycling through his scenes: idle, working on his laptop, celebrating, and asking for attention">
</p>

Craby is a **presence interface**: a desktop pet that any local "brain" can use as its face. Claude Code is the flagship integration — but the [HTTP protocol](PROTOCOL.md) is open, and anything that can `curl` can drive him. He solves the "is it done yet?" problem by always being in the corner of your eye:

- 😴 **Idle** — claws up, tapping slowly, blinking now and then (and when everything stays quiet for 10 minutes, he lies down and sleeps — Zzz)
- 💻 **Working** — hunched over a tiny laptop, hands hammering the keyboard
- 🔍 **On watch** — standing at attention with a magnifying glass or a crate, keeping vigil over something alive (a CI pipeline, a dev server, a container)
- 🎉 **Done** — pincers to the sky, confetti (with an optional *pling*)
- ❗ **Needs you** — waving at you with a blinking "!" (with an optional *ping*), and a small caption naming exactly who's calling

And the best part: when Claude asks for permission or has a question, a **speech bubble** opens under Craby and you can answer right there.

## Features

- **Watches your whole workflow, not just one tool** — an open [protocol](PROTOCOL.md) lets any local process report in: structured `/event` with source/session/state/project/detail/url, `/watch` for keeping vigil over long-lived things (alive/dead/gone), `/celebrate` for confetti, `/ask` for question bubbles. Claude Code is one client among many — the flagship one.
- **🧩 Addons** — teach Craby to watch new things by dropping a folder with an `addon.json` and an executable into `~/Library/Application Support/Craby/addons/`. Craby is the supervisor: he runs your executable on its interval, kills hung runs after 60 s, and hands it `CRABY_PORT`/`CRABY_SOURCE` (never the secret token). The manifest declares the addon's source, interval, scene and *costume* — props drawn in JSON. Two addons ship as **seeds**, copied to your folder as editable examples: **github-watch** (CI runs via `gh`, one repo per line in `repos.txt`) and **live-watch** (ports, PIDs and containers listed in `targets.txt`). Toggle each one in the menu bar under 🧩 Addons.
- **Visual addon builder** — open `http://localhost:4923` in a browser: the self-served playground has buttons to try every endpoint, plus a builder where you pick a scene, paint props cell by cell in each slot, and get the generated `addon.json` ready to save.
- **One outfit at a time** — the active source with the highest priority (`sourcePriority` in config; `claude` always wins while working) dresses the pet with its scene and props. Props from different sources never mix — Craby wears one costume, whole.
- **A redesigned crab with a real scene engine** — v3 art: eyes on stalks, a dome body, hand-like claws, 84 px on screen. Scenes are poses of the body (idle, hunched over the laptop — drawn *behind* the typing hands, standing vigil, celebrating with pincers up, lying down asleep, waving for attention); props are small grids anchored to named slots, with front/back layering and per-frame anchors.
- **Menu bar twin** — a mini animated crab in the menu bar, always in sync. Collapse the floating crab into the bar when you need a clean screen ("Collapse to the bar" in its menu).
- **Answer permissions from the bubble** — when Claude Code asks for permission, the bubble shows what it wants to run and *Allow / Deny / Terminal* buttons. Your click answers the real prompt via the official `PermissionRequest` hook. Dangerous-looking commands (`rm`, `push --force`, `sudo`…) get a red border. A fourth button, **Always allow**, shows the exact rule it will add (e.g. `Bash(git *)`) and writes it to your `permissions.allow` in `~/.claude/settings.json` (with a `.craby-bak` backup) — train your allowlist by clicking the crab.
- **Plan usage at a glance** — if a Claude Code OAuth token is available, Craby shows your subscription windows (5h session %, weekly %) in his tooltip and menu, and gets a worried sweat drop when the 5h window passes 80%. No token? The feature silently stays out of the way. Token lookup: `CLAUDE_CODE_OAUTH_TOKEN` env var → `~/.claude/.credentials.json` → `~/Library/Application Support/Craby/oauth-token` (paste the output of `claude setup-token` there) → macOS Keychain.
- **Celebrates your pushes** — `GET /celebrate` (or `craby celebrate "text"`) throws confetti and a toast. Ship it as a git hook with [`examples/git-hooks/pre-push`](examples/git-hooks/pre-push) and Craby parties on every `git push`.
- **Ask the user anything** — the local HTTP API lets Claude (or any script) ask multiple-choice or free-text questions through the bubble, with graceful fallback to the terminal.
- **You always know who's calling** — while attention is pending, a persistent caption near the pet names the caller ("ci: build failed"), and clicking the crab opens the caller's URL (the CI run, the PR…) or raises the window of the project that needs you (requires Accessibility permission).
- **Multi-session scoreboard** — running several sessions? The crab shows the highest-priority state across all of them, with white dots for parallel working sessions and a tooltip listing each project's status.
- **A brood of subagents** — when Claude Code spawns subagents, each one hatches as a baby crab in a strip below Craby: an egg cracks open with a *pop*, tiny legs drum away while the subagent runs, and when it finishes the little one retires with a cane for a couple of seconds and poofs into sparkles (*tink*). Failed or orphaned subagents poof in gray/red with a low *basso* thud — you can tell success from failure by ear alone. Up to 5 babies visible, session counts in Craby's tooltip ("· N 🐣"), reported by `GET /status`, powered by the official `SubagentStart`/`SubagentStop` hooks. As far as we know, no other coding-status pet turns your subagents into offspring.
- **Sounds with themes** — subtle cues for done/attention/hatch/poof, in three themes (Classic, Soft, Retro) plus per-event overrides. Done and attention play per finished session, from any source. Toggle and pick the theme in Preferences.
- **Craby speaks** — little toasts above his head: a good-morning greeting, task milestones, brood records, and a one-line summary of what each session just finished (extracted locally from the transcript — nothing leaves your machine).
- **Preferences window** — ntfy topic, sounds, sound theme, hide-on-screen-share and more, no config-file editing required (menu → Preferences).
- **`craby` CLI** — `craby status`, `craby ask "question" A B`, `craby input "question"`, `craby done`… the whole HTTP API with a friendly wrapper, installed to your PATH.
- **One-click updates** — when a new version is out, the menu offers "Update now": Craby downloads the release, swaps himself and restarts.
- **Presentation mode** — hides automatically while your screen is being shared (best effort; toggle in Preferences).
- **He's alive** — his eyes follow your mouse around the screen, he has spontaneous idle quirks (a little wave, a side-step, blowing a bubble), a sweat drop when a task runs long, a nap when nothing happens. On first launch he introduces himself.
- **Daily stats** — the menu bar shows what happened today (tasks finished, projects, time worked) and the last events — click one to jump to that project's window.
- **Phone alerts when you're away** — optional: if nobody touches the Mac for 2 minutes and something needs you, Craby pings your phone via [ntfy](https://ntfy.sh) (see Configuration).
- **Always visible, never in the way** — floats above every app, on every Space/virtual desktop, even over fullscreen apps. Never steals focus, no Dock icon, invisible to cmd-tab. Drag him anywhere; the position is remembered. Bubble shortcuts too: click a bubble, then press 1/2/3 to choose or Esc for the terminal.
- **English, Portuguese and Spanish** — UI follows your system language.
- **Safe by design** — if you don't answer a bubble in time, everything falls back to the normal terminal prompt. Craby never decides anything by himself, addons never see the secret token, and the endpoints that *inject decisions* require it.

## Install

Requirements: macOS 13+, `jq` (`brew install jq`), and [Claude Code](https://claude.com/claude-code).

**Homebrew**

```bash
brew tap duperez/craby
brew install --cask craby
"/Applications/Craby.app/Contents/Resources/setup.sh"   # connects Craby to Claude Code
```

**From source** (also needs Xcode Command Line Tools, `xcode-select --install`)

```bash
git clone https://github.com/duperez/crab-companion.git
cd crab-companion
./install.sh
```

**Prebuilt app** — grab `Craby.app.zip` from [Releases](https://github.com/duperez/crab-companion/releases), unzip into `/Applications`, run `xattr -dr com.apple.quarantine /Applications/Craby.app` (the app isn't code-signed), then run `setup.sh` inside `Craby.app/Contents/Resources/`.

Every path ends the same way: the app lands in `Applications/Craby.app` (zero dependencies), a LaunchAgent starts it at login, and the Claude Code hooks are added to `~/.claude/settings.json` — your previous config is backed up, and existing hooks on the same events are never overwritten. Restart any open Claude Code sessions and you're done. To remove everything: `./uninstall.sh`.

## How it works

```
Claude Code ── hooks ──┐
CI / servers ─ addons ─┼──> localhost:4923 ──> 🦀 (floating window + menu bar)
anything else ─ curl ──┘         ^                │
                                 └── decision (long-poll HTTP) ──┘
```

Everything speaks the same open [protocol](PROTOCOL.md) to the crab's local HTTP server. Claude Code plugs in via [hooks](https://code.claude.com/docs/en/hooks) on lifecycle events — each hook is a tiny script that POSTs to Craby:

| Hook event | Crab reaction |
|---|---|
| `UserPromptSubmit` | starts typing on the laptop |
| `PostToolUse` | heartbeat — keeps "working" alive (dead sessions go idle after 10 min without one) |
| `SubagentStart` / `SubagentStop` | a baby crab hatches below Craby / retires with a cane and poofs |
| `Stop` | celebrates (done) |
| `Notification` | waves for attention |
| `PermissionRequest` | opens the decision bubble and **waits for your click** |

The `PermissionRequest` flow is the fun one: the hook holds its connection open (long-poll) while the bubble is on screen. Your click travels back as the hook's stdout — an official permission decision — so the terminal prompt never even appears. No answer in ~45 s? The hook returns nothing and the normal prompt shows up. The crab never auto-approves anything.

## HTTP API

Anything on your machine can talk to the crab (full contract in [PROTOCOL.md](PROTOCOL.md)):

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
| `GET /answer/<allow\|deny\|ask\|opt:N\|txt:...>` | answer the current bubble programmatically (**token required**) |
| `GET /quit` | quit the app (**token required**) |

Bubble answers: `ask` means "user wants the terminal" — always treat it (and connection errors) as "fall back to the normal flow".

The two decision-injecting endpoints require a secret so no random local process can approve things on your behalf: pass `?token=$(cat "$HOME/Library/Application Support/Craby/token")` (or the `X-Craby-Token` header). The token is created on first launch, readable only by your user. Addons never receive it.

## Addons

An addon is a folder in `~/Library/Application Support/Craby/addons/<name>/` with two things: an `addon.json` manifest and an executable. Craby supervises it — runs the executable every `interval` seconds, watches over hung runs, and gives it `CRABY_PORT` and `CRABY_SOURCE` in the environment. The executable does one round of checking (poll `gh`, probe a port, `docker ps`…), reports via `/event` and `/watch`, and exits.

The manifest also declares the addon's **costume**: which scene Craby performs while this source is on top, and the props to stamp into that scene's slots — drawn right in the JSON:

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

The two factory seeds (**github-watch** and **live-watch**) are copied into your addons folder on first run as editable examples — open them, tweak them, break them, they're yours. Manage everything from the menu bar: 🧩 Addons → toggle each one, open the folder.

Don't want to hand-write grids? The playground at `http://localhost:4923` has a **visual builder**: pick a scene, paint the props cell by cell in every slot, and copy the generated `addon.json`.

## Configuration

Everything optional, all in `~/Library/Application Support/Craby/`:

- `config.json` — `{"ntfyTopic": "your-secret-topic"}` for phone alerts when you're away (subscribe to the same topic in the [ntfy app](https://ntfy.sh)); `{"sourcePriority": ["ci", "docker"]}` to decide which addon source dresses the pet when several are active (`claude` always comes first while working).
- `sprites.json` — reskin Craby entirely: character grids per state plus a palette. States you omit keep the default art; invalid grids are ignored.
- `stats.json` — Craby's memory (tasks, time worked, events). Delete it to start fresh.

## Works with any agent

The Claude Code hooks are just one client — the HTTP protocol is agent-agnostic. Anything that can `curl` can drive Craby: Codex CLI, Gemini CLI, cron jobs, CI scripts, long builds. The simplest integration is [`examples/craby-run`](examples/craby-run), a wrapper that marks a session as working, runs your command, and celebrates (or asks for attention on failure):

```bash
cp examples/craby-run /usr/local/bin/
craby-run npm run build
craby-run codex exec "refactor the tests"
```

For deeper integrations, write an addon (see above) or hit the endpoints directly — see [PROTOCOL.md](PROTOCOL.md).

## Let Claude ask you questions through the crab

Add this to your `~/.claude/CLAUDE.md` and Claude will prefer the bubble for quick questions:

```markdown
## Questions via Crab Companion
For short multiple-choice questions, before using AskUserQuestion, try:
curl -s --max-time 50 -X POST -H 'Content-Type: application/json' \
  -d '{"title":"[<project>] Claude has a question","detail":"<question>","urgent":false,"options":["A","B"]}' \
  http://localhost:4923/ask
Response `opt:N` = option index N; `txt:<text>` = typed answer (use `"input":true` instead of options);
`ask`/empty = fall back to AskUserQuestion.
```

## Development

Plain AppKit, no dependencies, split into small modules under [`Sources/`](Sources/): `Scenes.swift` (the scene/prop/slot engine), `Sprites.swift` (pixel art), `Addons.swift` (the supervisor), `Playground.swift` (the self-served page), `HTTPServer.swift`, `PlanUsage.swift`, `Stats.swift`, `Sounds.swift`, `L10n.swift`, `App.swift`. Scenes and props are character grids — editing Craby is literally editing text:

```
"....W..W....",
"...WBWWBW...",      R body   W/B eyes on stalks
"..RRRRRRRR..",      D shade  Y effects
".RRRRRRRRRR.",      props are stamped into slots
"RRRRRRRRRRRR",      ("garra", "mesa", "chao", "ceu"…)
```

A scene is a body pose (full frames) plus named slots; a prop is a small grid anchored to a slot, drawn in front of or behind the body, with per-frame anchors. The laptop in the working scene is itself a prop — drawn behind the typing hands.

Dev loop:

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

## License

[MIT](LICENSE) — built with [Claude Code](https://claude.com/claude-code), naturally. 🦀
