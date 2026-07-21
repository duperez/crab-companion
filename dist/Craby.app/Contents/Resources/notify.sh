#!/bin/bash
# Hook de notificação do Claude Code -> Craby.
# Uso nos hooks: notify.sh <working|done|attention|subagent-start|subagent-stop>
# Lê o JSON do hook no stdin e repassa sessão + projeto pro pet.
# No "done", extrai um resuminho da última resposta do transcript.

in=$(cat)
s=$(jq -r '.session_id // "default"' <<<"$in")
proj=$(basename "$(jq -r '.cwd // "?"' <<<"$in")")
p=$(printf %s "$proj" | jq -sRr @uri)

extra=""
if [ "$1" = "done" ]; then
  tp=$(jq -r '.transcript_path // empty' <<<"$in")
  if [ -n "$tp" ] && [ -f "$tp" ]; then
    sum=$(tail -n 80 "$tp" \
      | jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' 2>/dev/null \
      | tail -1 | tr '\n' ' ' | cut -c1-140)
    if [ -n "$sum" ]; then
      extra="&summary=$(printf %s "$sum" | jq -sRr @uri)"
    fi
  fi
fi

curl -s -m 2 "http://localhost:4923/$1?session=$s&project=$p$extra" >/dev/null 2>&1 || true
