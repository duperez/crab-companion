#!/bin/bash
# live-watch: vigia alvos listados em targets.txt e reporta vivo/morto.
# Formatos por linha:  port 4600 [label]  |  pid 123 [label]  |  container nome
set -u
PORT="${CRABY_PORT:-4923}"
SRC="${CRABY_SOURCE:-docker}"
cd "$(dirname "$0")" || exit 0

if [ ! -f targets.txt ]; then
  printf '# ex.:\n# port 4600 financas\n# container meu-app\n# pid 1234 worker\n' > targets.txt
  exit 0
fi

report() { # id label status
  curl -s -m 3 --get \
    --data-urlencode "id=$1" --data-urlencode "label=$2" \
    --data-urlencode "source=$SRC" --data-urlencode "status=$3" \
    "http://localhost:$PORT/watch" >/dev/null
}

while read -r kind target label; do
  case "$kind" in ''|'#'*) continue ;; esac
  [ -n "${label:-}" ] || label="$kind:$target"
  id="$kind-$target"
  alive=false
  case "$kind" in
    port) nc -z localhost "$target" >/dev/null 2>&1 && alive=true ;;
    pid) kill -0 "$target" >/dev/null 2>&1 && alive=true ;;
    container)
      docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$target" && alive=true ;;
  esac
  # só vira "dead" se já esteve vivo antes (evita alarme na configuração)
  statefile=".state-$id"
  if $alive; then
    echo up > "$statefile"
    report "$id" "$label" alive
  elif [ "$(cat "$statefile" 2>/dev/null)" = "up" ]; then
    echo down > "$statefile"
    report "$id" "$label" dead
  fi
done < targets.txt
exit 0
