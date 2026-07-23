#!/bin/bash
# github-watch: vigia os runs de CI dos repositórios listados em repos.txt
# (um owner/repo por linha). Precisa do `gh` autenticado.
set -u
PORT="${CRABY_PORT:-4923}"
SRC="${CRABY_SOURCE:-ci}"
cd "$(dirname "$0")" || exit 0

command -v gh >/dev/null 2>&1 || exit 0
if [ ! -f repos.txt ]; then
  printf '# um repositório por linha, ex.:\n# duperez/crab-companion\n' > repos.txt
  exit 0
fi

while read -r repo; do
  case "$repo" in ''|'#'*) continue ;; esac
  json=$(gh run list -R "$repo" -L 1 \
    --json databaseId,status,conclusion,url,displayTitle 2>/dev/null) || continue
  id=$(echo "$json" | jq -r '.[0].databaseId // empty')
  [ -n "$id" ] || continue
  status=$(echo "$json" | jq -r '.[0].status')
  conclusion=$(echo "$json" | jq -r '.[0].conclusion // ""')
  url=$(echo "$json" | jq -r '.[0].url')
  title=$(echo "$json" | jq -r '.[0].displayTitle' | head -c 40)

  statefile=".state-$(echo "$repo" | tr '/' '_')"
  last=$(cat "$statefile" 2>/dev/null || echo "")
  now="$id:$status:$conclusion"
  [ "$now" = "$last" ] && continue
  echo "$now" > "$statefile"

  proj=$(basename "$repo")
  case "$status:$conclusion" in
    in_progress:*|queued:*)
      curl -s -m 3 --get \
        --data-urlencode "source=$SRC" --data-urlencode "session=$repo" \
        --data-urlencode "state=working" --data-urlencode "project=$proj" \
        --data-urlencode "detail=CI: $title" --data-urlencode "url=$url" \
        "http://localhost:$PORT/event" >/dev/null ;;
    completed:success)
      curl -s -m 3 --get \
        --data-urlencode "source=$SRC" --data-urlencode "session=$repo" \
        --data-urlencode "state=done" --data-urlencode "project=$proj" \
        --data-urlencode "detail=CI verde: $title" --data-urlencode "url=$url" \
        "http://localhost:$PORT/event" >/dev/null ;;
    completed:*)
      curl -s -m 3 --get \
        --data-urlencode "source=$SRC" --data-urlencode "session=$repo" \
        --data-urlencode "state=attention" --data-urlencode "project=$proj" \
        --data-urlencode "detail=CI falhou: $title" --data-urlencode "url=$url" \
        "http://localhost:$PORT/event" >/dev/null ;;
  esac
done < repos.txt
exit 0
