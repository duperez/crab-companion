#!/bin/bash
# Hook de notificação do Claude Code -> Crab Companion.
# Uso nos hooks: notify.sh <working|done|attention>
# Lê o JSON do hook no stdin e repassa sessão + projeto pro pet.

in=$(cat)
s=$(jq -r '.session_id // "default"' <<<"$in")
proj=$(basename "$(jq -r '.cwd // "?"' <<<"$in")")
p=$(printf %s "$proj" | jq -sRr @uri)
curl -s -m 2 "http://localhost:4923/$1?session=$s&project=$p" >/dev/null 2>&1 || true
