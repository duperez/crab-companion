# Craby — Design & Architecture

This is the document for people who want to understand or contribute to Crab Companion. The [README](../README.md) tells you how to use it; [PROTOCOL.md](../PROTOCOL.md) is the contract external clients code against; this is the *why* and the *how inside*.

## The thesis: a presence interface

Craby is not a mascot with notifications bolted on — he is a **presence interface**: a face that any local "brain" (Claude Code via hooks, addons watching CI or containers, plain scripts) can borrow to show state. The pet solves the "is it done yet?" problem through peripheral vision: you never look *for* status, status lives in the corner of your eye.

Two principles follow from that:

- **An attention router, not a display.** The pet is one aggregated signal, not a dashboard. Many sessions and sources collapse into a single displayed state; who exactly is doing what lives in the tooltip and menu. Attribution appears only when something calls: while attention is pending, a caption names the caller and a click takes you to it. The rule of thumb: **attribution on call, anonymity in calm**.
- **Density proportional to urgency.** Idle is nearly silent (slow tapping, the occasional quirk). Working is ambient (typing animation, white dots for parallel sessions). Attention is the only loud state — blinking "!", caption, sound, and, if you're away, a phone ping. Anything wanting to be loud must pay the price of being urgent.

## The constitution

These rules are deliberate and non-negotiable without a project-level decision (contributors: don't "fix" them in passing):

1. **Scenes belong to the app; props belong to the addons.** The scene catalog (body poses) lives in `Sources/Scenes.swift` and only grows by changing the app. Addons never define scenes — they pick one from the catalog and declare props (JSON grids) stamped into its slots.
2. **One costume, never mixed.** The active source with the highest priority dresses the pet with its scene and props, exclusively. Props from different sources are never combined — Craby is one coherent character, not a Christmas tree of badges.
3. **Urgency has a single vocabulary, and it is not configurable.** `state=attention` and `watch status=dead` are the only ways to call the user. No addon-specific alarm sounds, custom blink patterns, or invented urgency states. Attention is expensive; everything else is done + toast.
4. **Addons never receive the token.** The supervisor hands them only `CRABY_PORT` and `CRABY_SOURCE`. The secret token gates the decision-injecting endpoints (`/answer`, `/quit`). Addons **inform and ask; they never decide**.
5. **Personality, not personalization.** The pet runs 100% on its own — no levels, rank hats, streaks, or unlockable cosmetics (all removed in v2). Progression mechanics make the pet about itself; Craby's charm must come from living behavior (eye tracking, idle quirks, the arrival cloud) that costs the user nothing.
6. **The canonical body is the "done" body.** Every scene starts from the same body — the 8/10/12/10 dome, stalk eyes, hand-like claws — and only limbs and eyes change pose between scenes. Never redraw the dome per scene.
7. **The pet never decides by itself.** An unanswered bubble times out (45 s, 90 s for free text) and falls back to the normal terminal prompt. That fallback is sacred — never remove it.

## Architecture

### Modules

Plain AppKit, zero dependencies, small files under `Sources/`:

| Module | Role |
|---|---|
| `App.swift` | the floating borderless window (all Spaces + fullscreen, `.accessory`, draggable, position persisted), menu bar twin, bubbles, captions, toasts, multi-session/multi-source state, brood of subagents, preferences, ntfy away-mode |
| `Scenes.swift` | the scene + prop + slot engine (see below) |
| `Sprites.swift` | pixel art as string grids (1 char = 1 pixel + palette), custom `sprites.json` loading |
| `Addons.swift` | the addon supervisor (see below) |
| `HTTPServer.swift` | `localhost:4923` on NWListener; token check for `/answer` and `/quit`; CORS |
| `Playground.swift` | the self-served page at `http://localhost:4923`: buttons for every endpoint + the visual addon builder (driven by `GET /scenes`) |
| `PlanUsage.swift` | Claude plan windows (5h/weekly) via OAuth token; silently absent without one |
| `Stats.swift` | daily stats and the event log (`stats.json`) |
| `Sounds.swift` | per-event sounds (done/attention/hatch/poof) with themes and overrides |
| `L10n.swift` | EN/PT/ES strings, following the system language |

Around the app: `notify.sh` (the state hooks: extracts `session_id`/`cwd` from hook stdin, GETs `/{state}`), `ask.sh` (the `PermissionRequest` hook: POSTs `/ask`, translates the answer into an official permission decision on stdout), `bin/craby` (the CLI wrapper), `addons/` (the two factory seeds), `setup.sh`/`package.sh`/`install.sh` (bundle, LaunchAgent, hooks), `tools/main.swift` (renders the icon and demo GIF frames).

### The scene engine

A **scene** is a body pose: complete 14x14 frames plus named **slots** (`cabeca`, `mesa`, `garra`, `chao`, `ceu`, `acima`…). A **prop** is a small character grid stamped into a slot (`.` = transparent). Three details make the engine expressive rather than a sticker system:

- **Per-frame anchors.** A slot's position is an array indexed by frame, so a prop rides the body's animation — it bobs when the crab bobs.
- **Front/back layering.** A slot can be marked `behind`, stamped with `stampBehind` so the body draws over it. That's how the laptop in the working scene sits *behind* the typing hands — the hands animate over a static prop.
- **Defensive validation.** A prop larger than its slot's `maxW`/`maxH`, or an empty/invalid grid, is silently skipped. A broken addon can never corrupt the render.

Scene catalog: `idle`, `debrucado` (working — the laptop itself is a prop), `atento` (the default addon scene), `comemorando`, `deitado`, and `atencao` (a global face with no addon slots — see constitution rule 3). `GET /scenes` exports the catalog (first frame, slots with anchor and max size, palette) — it is the single source the visual builder draws from.

### The addon supervisor

Addons are the packaged form of a brain: a folder with `addon.json` + an executable, supervised by Craby so watchers need no launchd/cron of their own.

- **Seeds.** The bundled addons (`github-watch`, `live-watch`) are copied into `~/Library/Application Support/Craby/addons/` on first run as editable examples. Craby never reads the bundle copies afterwards — the user's copy is the truth.
- **Scheduling.** Each enabled addon's `exec` runs every `interval` seconds (minimum 5, first run immediate when toggled on). One run = one round: poll the real thing, report via `/event`/`/watch`, exit. Disabled addons are simply not scheduled.
- **Watchdog.** A run still alive after 60 s is terminated.
- **Environment.** `CRABY_PORT` and `CRABY_SOURCE` on top of the user environment — never the token (constitution rule 4).

### The flow of an event

```
hook / addon / script
        │  GET /event, /watch, /working…
        ▼
HTTPServer (localhost:4923)
        ▼
session table — keyed source:session, so ids never collide across sources
        ▼
recompute displayed state ──► render scene + winning costume
```

Aggregation rules:

- **Across sessions:** the displayed state is the highest priority among all live sessions — `attention > working > done > idle`.
- **Across sources:** the winning source dresses the pet. `claude` always wins while working; among addon sources, `sourcePriority` (default `["ci", "docker"]`) breaks ties.
- **Hygiene:** sessions expire after 4 h without events; a working session goes stale (→ idle) after 10 min without a heartbeat (`PostToolUse` is the heartbeat). Watches never expire on their own — the watcher must send `gone`.

The question flow is the same pipe run backwards: `/ask` long-polls while the bubble is on screen, and the user's click travels back as the HTTP response — which, for the `PermissionRequest` hook, becomes the hook's stdout and therefore an official permission decision. Timeout → `ask` → terminal (constitution rule 7).

## Notable decisions

**`moveToActiveSpace`, for the sake of a cloud.** The obvious choice for an always-visible pet is `canJoinAllSpaces`. Craby instead lives in *one* Space and teleports: on `activeSpaceDidChange` he rides away with the old screen and materializes on the new one out of a little magic cloud. The window behavior was chosen to make an animation possible — presence should feel like a creature arriving, not a sticker glued to the monitor. (Bubbles and toasts do join all Spaces; a question must never be missed for theatrical reasons.)

**Sound per event, not per showcase.** Sounds attach to the event vocabulary — done, attention, hatch, poof (success/failure) — never to a specific source or costume. Any source's completion plays *the* done sound. This keeps the audio channel learnable (you can tell success from failure by ear alone) and enforces constitution rule 3 in the sound domain: addons can't invent their own sirens.

**Exclusive costume.** Merging props from simultaneously active sources was considered and rejected: it turns the pet into a notification tray. One winning source wearing one whole costume keeps the character readable at a glance — you see *a crab keeping vigil for CI*, not a crab covered in badges.

**CORS restricted to the official site.** The HTTP server echoes `Access-Control-Allow-Origin` for exactly one origin, `https://duperez.github.io`, so the website's live playground can talk to your local crab while arbitrary web pages cannot read responses from `localhost:4923`. Defense in depth: even the allowed origin can't inject decisions — `/answer` and `/quit` still require the local token, which only the user (and never addons or browsers) can read.
