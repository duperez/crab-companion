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
GET /answer/<answer>?token=<t>    → answer the current bubble (token required)
GET /quit?token=<t>               → quit (token required)
GET /subagent-start|subagent-stop?session=<id>[&failed=1]
```

Token: `~/Library/Application Support/Craby/token` (created on first launch,
mode 0600). Only decision-injecting endpoints require it.

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
