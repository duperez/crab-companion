#!/bin/bash
# Hook PermissionRequest do Claude Code -> balão de pergunta do claude-pet.
# Lê o pedido no stdin, mostra no balão e espera a escolha do usuário.
# Sem resposta (timeout/pet desligado): não imprime nada -> prompt normal no terminal.

INPUT=$(cat)

PROJ=$(basename "$(echo "$INPUT" | jq -r '.cwd // ""')")
TOOL=$(echo "$INPUT" | jq -r '.tool_name // "?"')
case "$TOOL" in
  Bash)
    DETAIL=$(echo "$INPUT" | jq -r '.tool_input.command // ""' | head -c 150)
    TITLE="Claude quer rodar um comando"
    ;;
  Edit|Write|NotebookEdit)
    DETAIL=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
    TITLE="Claude quer editar um arquivo"
    ;;
  *)
    DETAIL=$(echo "$INPUT" | jq -r '.tool_input | tostring' | head -c 150)
    TITLE="Claude quer usar: $TOOL"
    ;;
esac

if [ -n "$PROJ" ] && [ "$PROJ" != "." ] && [ "$PROJ" != "/" ]; then
  TITLE="[$PROJ] $TITLE"
fi

URGENT=false
if echo "$DETAIL" | grep -qiE '(^|[^a-z])(rm|sudo|drop|delete|truncate)([^a-z]|$)|--force|push|reset --hard|deploy'; then
  URGENT=true
fi

PAYLOAD=$(jq -n --arg t "$TITLE" --arg d "$DETAIL" --argjson u "$URGENT" \
  '{title: $t, detail: $d, urgent: $u}')

ANSWER=$(echo "$PAYLOAD" | curl -s --max-time 50 -X POST \
  -H 'Content-Type: application/json' -d @- http://localhost:4923/ask)

case "$ANSWER" in
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
