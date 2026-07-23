#!/bin/bash
# Hook PermissionRequest do Claude Code -> balão de pergunta do claude-pet.
# Lê o pedido no stdin, mostra no balão e espera a escolha do usuário.
# Sem resposta (timeout/pet desligado): não imprime nada -> prompt normal no terminal.

INPUT=$(cat)

PROJ=$(basename "$(echo "$INPUT" | jq -r '.cwd // ""')")
TOOL=$(echo "$INPUT" | jq -r '.tool_name // "?"')
RULE=""
case "$TOOL" in
  Bash)
    DETAIL=$(echo "$INPUT" | jq -r '.tool_input.command // ""' | head -c 150)
    TITLE="Claude quer rodar um comando"
    # regra sugerida p/ "Sempre permitir": prefixo pelo 1º comando (ex. Bash(git *))
    FIRST=$(echo "$DETAIL" | awk '{print $1}')
    if echo "$FIRST" | grep -qE '^[A-Za-z0-9_./-]+$'; then
      RULE="Bash($FIRST *)"
    fi
    ;;
  Edit|Write|NotebookEdit)
    DETAIL=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
    TITLE="Claude quer editar um arquivo"
    RULE="$TOOL"
    ;;
  *)
    DETAIL=$(echo "$INPUT" | jq -r '.tool_input | tostring' | head -c 150)
    TITLE="Claude quer usar: $TOOL"
    if echo "$TOOL" | grep -qE '^[A-Za-z0-9_]+$'; then
      RULE="$TOOL"
    fi
    ;;
esac

if [ -n "$PROJ" ] && [ "$PROJ" != "." ] && [ "$PROJ" != "/" ]; then
  TITLE="[$PROJ] $TITLE"
fi

# urgência: comandos realmente destrutivos/irreversíveis, com fronteira de
# palavra pra evitar falso positivo (ex.: "pushd", "warmup", "format")
URGENT=false
if echo "$DETAIL" | grep -qiE \
  '(^|[;&|[:space:]])(sudo|mkfs|shutdown|reboot|killall)([[:space:]]|$)|(^|[;&|[:space:]])rm[[:space:]]+-|--force|--hard|(^|[[:space:]])(drop|truncate)[[:space:]]+(table|database)|git[[:space:]]+push|dd[[:space:]]+if='; then
  URGENT=true
fi

PAYLOAD=$(jq -n --arg t "$TITLE" --arg d "$DETAIL" --arg r "$RULE" --argjson u "$URGENT" \
  '{title: $t, detail: $d, urgent: $u, rule: (if $r == "" then null else $r end)}')

ANSWER=$(echo "$PAYLOAD" | curl -s --max-time 50 -X POST \
  -H 'Content-Type: application/json' -d @- http://localhost:4923/ask)

case "$ANSWER" in
  always)
    # "Sempre permitir": grava a regra na allowlist global (com backup)
    # e permite desta vez; se algo falhar, o clique vale como "permitir"
    SETTINGS="$HOME/.claude/settings.json"
    if [ -n "$RULE" ] && [ -f "$SETTINGS" ] && command -v jq >/dev/null 2>&1; then
      cp "$SETTINGS" "$SETTINGS.craby-bak" 2>/dev/null || true
      if jq --arg r "$RULE" \
        '.permissions.allow = (((.permissions.allow // []) + [$r]) | unique)' \
        "$SETTINGS" > "$SETTINGS.craby-tmp" 2>/dev/null \
        && [ -s "$SETTINGS.craby-tmp" ]; then
        mv "$SETTINGS.craby-tmp" "$SETTINGS"
      else
        rm -f "$SETTINGS.craby-tmp"
      fi
    fi
    echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
    ;;
  allow)
    echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
    ;;
  deny)
    echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny"}},"additionalContext":"Negado pelo usuário via claude-pet (balão de permissão)"}'
    ;;
  *)
    # "ask", vazio ou erro: deixa o fluxo normal do terminal acontecer
    ;;
esac
exit 0
