# Craby Protocol v1

Craby is a **presence interface**: a desktop pet that any local "brain" can use
as its face. Claude Code is the flagship brain, but anything that can speak
HTTP to `localhost:4923` can show state, celebrate, ask for attention, or ask
the user a question through the crab.

This document is the contract external clients ("brains" / addons) code
against. Legacy endpoints remain supported forever; new clients should prefer
the structured ones.

## Concepts

- **Event** — something happened in a session: it started working, finished,
  failed, or needs the user. Craby aggregates all sessions and displays the
  highest-priority state (`attention > working > done > idle`).
- **Watch** — something long-lived (a dev server, a container) that Craby
  keeps an eye on. Alive watches are listed in the tooltip and menu; a dead
  watch raises an attention event.
- **Source** — who is emitting: `claude`, `ci`, `docker`, or any short slug.
  Sources give attribution in the tooltip/menu. The pet itself stays a single
  aggregated signal ("attribution on call, anonymity in calm").
- **Ask** — a question bubble. Long-polls until the user clicks.

## Endpoints

Base URL: `http://localhost:4923`

### Playground (try it out)

Open `http://localhost:4923` in a browser: a self-served page with buttons and
forms for every endpoint below — states, events, watches, celebrations and
question bubbles. Great for demos and for testing a new integration by hand.

### Structured event (preferred)

```
GET /event?source=ci&session=<id>&state=working|done|attention|idle
          [&project=<name>][&detail=<short text>][&url=<link>]
```

- `state=attention` + `url`: clicking the pet opens the URL (CI run, PR…).
  While attention is pending, a small caption near the pet names the caller.
- `detail` feeds the caption/toast (keep it under ~60 chars).
- Sessions are keyed `source:session`; the same id from different sources
  never collides.

### Watch (long-lived things)

```
GET /watch?id=<unique>&label=<display name>[&source=<slug>][&url=<link>]
          [&status=alive|dead|gone]
```

- `alive` (default): register or heartbeat. Shows as 🟢 in menu/tooltip.
- `dead`: marks 🔴 and raises an attention event ("<label> went down!").
- `gone`: silently removes the watch (thing was intentionally stopped).

The watcher process is responsible for polling the real thing (port, PID,
container) and reporting; Craby only reflects what it is told.

### Celebration

```
GET /celebrate[?text=<toast text>]
```

Confetti + sound + toast. Used by the `pre-push` git hook example.

### Legacy state endpoints (Claude Code hooks use these)

```
GET /working|done|attention|idle?session=<id>[&project=<name>][&summary=<text>]
```

Equivalent to `/event` with `source=claude`.

### Questions (bubble)

```
POST /ask   {"title","detail","urgent"}                → allow | deny | ask
POST /ask   {..., "rule": "Bash(git *)"}               → + always (writes allowlist)
POST /ask   {..., "options": ["A","B"]}                → opt:0 | opt:1 | … | ask
POST /ask   {..., "input": true}                       → txt:<typed> | ask
```

Long-polls until the user clicks (45s/90s timeout → `ask`). Treat `ask`,
empty responses and connection errors as "fall back to your normal flow".

### Introspection & control

```
GET /status                       → JSON: version, displayed, totalTasks,
                                    subagents, sessions[], watches[]
GET /scenes                       → JSON: scene catalog (first frame + slots
                                    with anchor/max size) and the palette —
                                    what the playground addon builder uses
GET /answer/<answer>?token=<t>    → answer the current bubble (token required)
GET /quit?token=<t>               → quit (token required)
GET /subagent-start|subagent-stop?session=<id>[&failed=1]
```

Token: `~/Library/Application Support/Craby/token` (created on first launch,
mode 0600). Only decision-injecting endpoints require it. Addons never
receive the token.

## Addons

An addon is the packaged form of a brain: a folder Craby supervises, so the
watcher process needs no launchd/cron of its own.

### Folders

- `~/Library/Application Support/Craby/addons/<name>/` — where all addons
  live. Menu bar → 🧩 Addons → "open folder" gets you there.
- The addons bundled with the app (`github-watch`, `live-watch`) are
  **seeds**: on first run they are copied into the user folder as editable
  examples. Craby never reads them from the bundle afterwards — the user's
  copy is the truth.

### Manifest (`addon.json`)

```json
{
  "name": "github-watch",
  "description": "GitHub CI on the pet (gh)",
  "exec": "run.sh",
  "source": "ci",
  "interval": 30,
  "scene": "atento",
  "props": { "garra": ["CW.", "CCG", "..G"] },
  "cores": { "C": "#4078c0" }
}
```

| Field | Required | Meaning |
|---|---|---|
| `name` | yes | unique addon id (also the default `source`) |
| `exec` | yes | executable inside the addon folder, run each cycle |
| `description` | no | shown in the 🧩 Addons menu |
| `source` | no | source slug used in events and in `sourcePriority` (default: `name`) |
| `interval` | no | seconds between runs (default 30, minimum 5) |
| `scene` | no | scene from the catalog the pet performs while this source is on top: `idle`, `atento` (default), `debrucado`, `comemorando`, `deitado` |
| `props` | no | the costume: `{ "<slot>": ["row", "row", …] }` grids stamped into the scene's slots (`.` = transparent) |
| `cores` | no | extra palette entries, `{ "<char>": "#rrggbb" }` |

Scenes belong to the app; addons only pick one and dress it. Slots and their
sizes come from `GET /scenes`. The active source with the highest priority
wears its scene+props exclusively — props from different sources never mix.

### Supervisor behavior

- Each enabled addon's `exec` runs every `interval` seconds (first run
  immediately when toggled on). One run = one round of checking: poll the
  real thing, report via `/event` and `/watch`, exit.
- Watchdog: a run still alive after 60 s is terminated.
- Environment: the process gets `CRABY_PORT` (4923) and `CRABY_SOURCE` (the
  resolved source slug) on top of the user environment. It never gets the
  secret token — addons can inform and ask, not decide.
- Enable/disable per addon in the menu bar (🧩 Addons); disabled addons are
  simply not scheduled.

### Building one without hand-writing grids

The playground at `http://localhost:4923` includes a visual builder: pick a
scene, paint props cell by cell in each slot, and copy the generated
`addon.json` into a new folder next to the seeds.

## Rules for well-behaved brains

1. **Attention is expensive.** Reserve `state=attention` / `status=dead` for
   things the user should act on now. Prefer `done` + toast for FYI.
2. **Always fall back.** If Craby is not running (connection refused), carry
   on silently. Never block on the pet.
3. **One session per thing.** Use stable session/watch ids so updates replace
   instead of piling up.
4. **Short strings.** `detail`/`label` should read at a glance.
5. Sessions expire after 4h without events; working sessions go stale after
   10min without a heartbeat. Watches never expire on their own — send `gone`.

## Versioning

This is protocol v1. Fields are only ever added, never removed or renamed;
unknown query parameters are ignored.
