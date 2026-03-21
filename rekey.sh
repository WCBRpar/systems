#!/usr/bin/env nix-shell
#!nix-shell -i bash -p git age ssh-to-age

# Script de rekey para agenix-rekey
# Uso: ./rekey.sh [host-name]
# Se nenhum host for especificado, faz rekey de todos os hosts

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔄 agenix-rekey: Re-encryptando secrets..."
echo ""

# Determina qual host rekeyar
if [ -n "$1" ]; then
    HOST_FILTER="--host $1"
    echo "🎯 Rekeying apenas para o host: $1"
else
    HOST_FILTER=""
    echo "🎯 Rekeying para TODOS os hosts"
fi

# Executa o rekey usando nix run para evitar dependência de instalação global
# Isso usa o input do flake local, evitando downloads repetidos da internet
echo ""
echo "📝 Executando agenix-rekey via nix run..."
nix run ".#agenix-rekey" -- rekey \
    --secrets-file secrets/secrets.nix \
    --rekey-file secrets/rekey.nix \
    $HOST_FILTER \
    --age-secrets-directory secrets/

echo ""
echo "✅ Rekey concluído com sucesso!"
echo ""
echo "📋 Próximos passos:"
echo "   1. Verifique as mudanças: git diff secrets/*.age"
echo "   2. Commit as mudanças: git add secrets/*.age && git commit -m 'chore: rekey secrets'"
echo "   3. Deploy nos hosts: nixos-rebuild switch --flake .#<hostname>"
