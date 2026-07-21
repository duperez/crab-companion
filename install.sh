#!/bin/bash
# Instala o Craby a partir do código-fonte: compila, monta o .app em
# ~/Applications e conecta ao Claude Code (LaunchAgent + hooks).
set -euo pipefail
cd "$(dirname "$0")"

command -v swiftc >/dev/null 2>&1 || {
  echo "erro: swiftc não encontrado. Instale o Xcode Command Line Tools: xcode-select --install"
  echo "      (ou baixe o app pronto em https://github.com/duperez/crab-companion/releases)"
  exit 1
}
command -v jq >/dev/null 2>&1 || {
  echo "erro: jq não encontrado. Instale com: brew install jq"
  exit 1
}

echo "==> Compilando"
swiftc Sources/*.swift -o pet

./package.sh

echo "==> Instalando em ~/Applications/Craby.app"
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/Craby.app"
cp -R dist/Craby.app "$HOME/Applications/Craby.app"

"$HOME/Applications/Craby.app/Contents/Resources/setup.sh"
