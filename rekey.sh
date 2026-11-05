#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ $# -gt 0 ]]; then
  echo "O app upstream configurado processa os hosts elegíveis do flake; o filtro --host antigo não está disponível." >&2
  echo "Execute ./rekey.sh sem argumentos ou consulte 'nix run .#agenix-rekey.x86_64-linux.rekey -- --help'." >&2
  exit 2
fi

exec nix run ".#agenix-rekey.x86_64-linux.rekey" -- --add-to-git
