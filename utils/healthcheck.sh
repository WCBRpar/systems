#!/usr/bin/env bash
# health-check.sh – Verificação de saúde pós-rebuild
# Autor: WCBRpar
# Uso:   ./health-check.sh [--quiet]
# Requer: curl, openssl, systemctl, journalctl

set -euo pipefail

# ------------------------------------------------------------
# Configurações – ajuste conforme seu ambiente
# ------------------------------------------------------------
# Sites WordPress / websites estáticos
declare -A SITES=(
  ["adufms.org.br"]="https://adufms.org.br"
  ["cutms.org.br"]="https://cutms.org.br"
  ["humbertoamaducci.com.br"]="https://humbertoamaducci.com.br"
  ["esperancavermelha.com.br"]="https://esperancavermelha.com.br"
  ["setra.com.br"]="https://setra.com.br"
  ["social.redcom.digital"]="https://social.redcom.digital"
)

# Sites Odoo (CRM) – verificação de login
declare -A ODOO_SITES=(
  ["crm.wcbrpar.com"]="https://crm.wcbrpar.com/web/login"
  ["crm.redcom.digital"]="https://crm.redcom.digital/web/login"
  ["brtintas.com.br"]="https://brtintas.com.br/web/login"
  ["novo.adufms.org.br"]="https://novo.adufms.org.br/web/login"
  ["pt13ms.org.br"]="https://pt13ms.org.br/web/login"
  # adicione outros domínios Odoo que precisar verificar
)

# Serviços systemd essenciais
SERVICES=(
  "traefik"
  "nginx"
  "odoo"
  "postgresql"   # ou "mysql" se for o caso
  "phpfpm"
)

# Tempo máximo (segundos) para cada requisição HTTP
CURL_TIMEOUT=10

# ------------------------------------------------------------
# Cores
# ------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ------------------------------------------------------------
# Funções auxiliares
# ------------------------------------------------------------
log_ok()   { echo -e "${GREEN}OK${NC}   $*"; }
log_fail() { echo -e "${RED}FAIL${NC} $*"; }
log_warn() { echo -e "${YELLOW}WARN${NC} $*"; }

# Verifica se um endpoint HTTP responde 2xx e contém o conteúdo esperado (opcional)
check_http() {
  local name="$1"
  local url="$2"
  local expected="${3:-}"

  printf "→ HTTP  %-30s " "$name"
  local body
  if ! body=$(curl -sS --fail --max-time "$CURL_TIMEOUT" -L "$url" 2>&1); then
    log_fail "curl error: $body"
    return 1
  fi

  if [[ -n "$expected" ]] && ! grep -q "$expected" <<< "$body"; then
    log_fail "conteúdo esperado não encontrado: $expected"
    return 1
  fi

  log_ok "($url)"
  return 0
}

# Verifica se um serviço systemd está ativo
check_service() {
  local svc="$1"
  printf "→ SVC   %-30s " "$svc"
  if systemctl is-active --quiet "$svc"; then
    log_ok "ativo"
    return 0
  else
    log_fail "inativo"
    return 1
  fi
}

# Verifica validade do certificado SSL (mínimo 24h de validade)
check_ssl() {
  local domain="$1"
  printf "→ SSL   %-30s " "$domain"
  if openssl s_client -servername "$domain" -connect "$domain:443" </dev/null 2>/dev/null \
       | openssl x509 -noout -checkend 86400 >/dev/null 2>&1; then
    log_ok "válido (>24h)"
    return 0
  else
    log_fail "inválido ou expirando em <24h"
    return 1
  fi
}

# Verifica se há erros recentes nos logs de um serviço
check_logs() {
  local svc="$1"
  local since="${2:-"5 minutes ago"}"
  printf "→ LOG   %-30s " "$svc (desde $since)"
  local errs
  if errs=$(journalctl -u "$svc" --since "$since" --no-pager -p err 2>/dev/null | grep -v '^--' || true); then
    if [[ -n "$errs" ]]; then
      log_warn "erros encontrados (últimas 5 linhas):"
      echo "$errs" | tail -5 | sed 's/^/      /'
      return 1
    fi
  fi
  log_ok "sem erros"
  return 0
}

# ------------------------------------------------------------
# Execução principal
# ------------------------------------------------------------
main() {
  local failures=0
  local quiet=false
  [[ "${1:-}" == "--quiet" ]] && quiet=true

  echo "=============================================="
  echo "  HEALTH CHECK – $(date '+%Y-%m-%d %H:%M:%S')"
  echo "=============================================="

  # 1) Sites WordPress / estáticos
  echo -e "\n[1] Websites (WordPress / estáticos)"
  for name in "${!SITES[@]}"; do
    check_http "$name" "${SITES[$name]}" "WordPress" || ((failures++))
  done

  # 2) Sites Odoo (verifica página de login)
  echo -e "\n[2] Odoo (CRM)"
  for name in "${!ODOO_SITES[@]}"; do
    check_http "$name" "${ODOO_SITES[$name]}" "Odoo" || ((failures++))
  done

  # 3) Serviços systemd
  echo -e "\n[3] Serviços systemd"
  for svc in "${SERVICES[@]}"; do
    check_service "$svc" || ((failures++))
  done

  # 4) Certificados SSL (para todos os domínios)
  echo -e "\n[4] Certificados SSL"
  for domain in "${!SITES[@]}"; do
    check_ssl "$domain" || ((failures++))
  done
  for domain in "${!ODOO_SITES[@]}"; do
    check_ssl "$domain" || ((failures++))
  done

  # 5) Logs de erro recentes
  echo -e "\n[5] Logs de erro (últimos 5 min)"
  for svc in "${SERVICES[@]}"; do
    check_logs "$svc" || ((failures++))
  done

  # Resultado final
  echo -e "\n=============================================="
  if [[ $failures -eq 0 ]]; then
    echo -e "${GREEN}✅ Todos os checks passaram!${NC}"
    exit 0
  else
    echo -e "${RED}❌ $failures check(s) falharam.${NC}"
    exit 1
  fi
}

main "$@"
