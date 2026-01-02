#!/usr/bin/env bash
# verify-rfaa-server-wordpress.sh
# Verificação completa (servidor + OpenLiteSpeed + TLS/LE + WordPress).
# Uso:
#   sudo bash verify-rfaa-server-wordpress.sh
#   sudo DOMAIN_MAIN=rfaa.com.br DOMAIN_WWW=www.rfaa.com.br WEBROOT=/var/www/rfaa bash verify-rfaa-server-wordpress.sh
# Saída: imprime relatório e salva em /root/verify_rfaa_report_<timestamp>.log

set -euo pipefail

DOMAIN_MAIN="${DOMAIN_MAIN:-rfaa.com.br}"
DOMAIN_WWW="${DOMAIN_WWW:-www.rfaa.com.br}"
DOMAIN_DEV="${DOMAIN_DEV:-www2.rfaa.com.br}"
WEBROOT="${WEBROOT:-/var/www/rfaa}"

LSWS_BIN="${LSWS_BIN:-/usr/local/lsws/bin/lswsctrl}"
LSWS_CONF="${LSWS_CONF:-/usr/local/lsws/conf/httpd_config.conf}"
VHOST_CONF="${VHOST_CONF:-/usr/local/lsws/conf/vhosts/rfaa/vhconf.conf}"
ADMIN_CONF="${ADMIN_CONF:-/usr/local/lsws/admin/conf/admin_config.conf}"

REPORT="/root/verify_rfaa_report_$(date +%F_%H%M%S).log"
exec > >(tee -a "$REPORT") 2>&1

ok(){ printf "[OK] %s\n" "$*"; }
warn(){ printf "[WARN] %s\n" "$*"; }
fail(){ printf "[FAIL] %s\n" "$*"; }
section(){ printf "\n========== %s ==========\n" "$*"; }

need_cmd(){
  command -v "$1" >/dev/null 2>&1 || { fail "Comando ausente: $1"; return 1; }
  ok "Comando disponível: $1"
}

try(){
  # não derruba o script
  set +e
  "$@"
  local rc=$?
  set -e
  return $rc
}

curlh(){
  local url="$1"
  curl -sS -D- -o /dev/null --max-time 12 -H "Connection: close" "$url" | tr -d '\r'
}

curlhl(){
  local url="$1"
  curl -sS -I -L --max-redirs 15 --max-time 20 -H "Connection: close" "$url" | tr -d '\r'
}

resolve_ip(){
  local host="$1"
  getent ahostsv4 "$host" 2>/dev/null | awk 'NR==1{print $1}'
}

section "1) Ambiente / comandos"
need_cmd ss || true
need_cmd systemctl || true
need_cmd journalctl || true
need_cmd curl || true
need_cmd openssl || true
need_cmd grep || true
need_cmd awk || true
need_cmd sed || true
need_cmd getent || true
need_cmd dig || warn "dig não encontrado (ok, vou usar getent)"
need_cmd php || warn "php não encontrado (alguns checks WP serão limitados)"
need_cmd certbot || warn "certbot não encontrado (checks LE serão limitados)"
need_cmd mysql || warn "mysql client não encontrado (checks DB serão limitados)"

section "2) SO / rede / IPs"
echo "Hostname: $(hostname -f 2>/dev/null || hostname)"
echo "Data: $(date -u) (UTC) / $(date)"
echo "Kernel: $(uname -a)"
echo "Uptime: $(uptime -p 2>/dev/null || true)"
echo "IPs locais:"
ip -br a 2>/dev/null || ifconfig 2>/dev/null || true

echo
echo "Resolução DNS (getent):"
for d in "$DOMAIN_MAIN" "$DOMAIN_WWW" "$DOMAIN_DEV"; do
  printf "%-20s -> %s\n" "$d" "$(resolve_ip "$d" || echo 'N/A')"
done

section "3) Serviços (lsws/apache/nginx) e portas"
echo "Portas 80/443/7080 em escuta:"
ss -lntp | egrep ':(80|443|7080)\b' || true

echo
echo "Status OpenLiteSpeed (lshttpd):"
try systemctl status lshttpd.service --no-pager || true
try systemctl status lshttpd --no-pager || true
echo
echo "Status Apache/Nginx (se existir):"
try systemctl status apache2 --no-pager || true
try systemctl status nginx --no-pager || true

section "4) Logs recentes do LiteSpeed (erros relevantes)"
if [ -f /usr/local/lsws/logs/error.log ]; then
  tail -n 120 /usr/local/lsws/logs/error.log | egrep -i "error|fatal|permission denied|listener|certificate|ocsp|rewrite|redirect|loop|fail" || true
else
  warn "Não encontrei /usr/local/lsws/logs/error.log"
fi

section "5) Configuração OpenLiteSpeed (sanidade básica)"
if [ -f "$LSWS_CONF" ]; then
  ok "Arquivo encontrado: $LSWS_CONF"
  echo "Trechos (listeners/virtualhost/maps) de $LSWS_CONF:"
  egrep -n "^(virtualhost|listener)\b|^\s*(address|secure|map|keyFile|certFile)\b" "$LSWS_CONF" | sed -n '1,240p' || true
else
  fail "Não encontrei: $LSWS_CONF"
fi

if [ -f "$VHOST_CONF" ]; then
  ok "Arquivo encontrado: $VHOST_CONF"
  echo "Trechos (docRoot/vhDomain/context/rewrite/header) de $VHOST_CONF:"
  egrep -n "^(docRoot|vhDomain|context|rewrite|header)\b|^\s*(location|RewriteRule|RewriteCond|add)\b" "$VHOST_CONF" | sed -n '1,260p' || true
else
  warn "Não encontrei: $VHOST_CONF"
fi

section "6) Testes HTTP/HTTPS (redirects / loops / headers)"
echo "HTTP -> (seguindo redirects) $DOMAIN_MAIN:"
curlhl "http://$DOMAIN_MAIN/" | egrep -i '^HTTP/|^location:|^server:' || true

echo
echo "HTTP -> (seguindo redirects) $DOMAIN_WWW:"
curlhl "http://$DOMAIN_WWW/" | egrep -i '^HTTP/|^location:|^server:' || true

echo
echo "HTTPS -> (seguindo redirects) $DOMAIN_MAIN:"
curlhl "https://$DOMAIN_MAIN/" | egrep -i '^HTTP/|^location:|^server:' || true

echo
echo "HTTPS -> (seguindo redirects) $DOMAIN_WWW:"
curlhl "https://$DOMAIN_WWW/" | egrep -i '^HTTP/|^location:|^server:' || true

echo
echo "Checagem rápida de loop (contando 301/302):"
for u in "http://$DOMAIN_MAIN/" "http://$DOMAIN_WWW/" "https://$DOMAIN_MAIN/" "https://$DOMAIN_WWW/"; do
  c="$(curl -sS -I -L --max-redirs 15 --max-time 20 "$u" | tr -d '\r' | egrep -c '^HTTP/1\.[01] 30[12]')"
  printf "%-35s redirects(301/302)=%s\n" "$u" "$c"
done

echo
echo "Headers de segurança (apenas resposta final de https://$DOMAIN_MAIN):"
curl -sS -D- -o /dev/null --max-time 15 "https://$DOMAIN_MAIN/" | tr -d '\r' \
  | egrep -i '^(HTTP/|strict-transport-security:|x-frame-options:|x-content-type-options:|referrer-policy:|permissions-policy:|content-security-policy:|server:)'

section "7) Teste ACME webroot (Let’s Encrypt http-01)"
ACME_DIR="$WEBROOT/.well-known/acme-challenge"
ACME_FILE="$ACME_DIR/verify-$(date +%s).txt"
mkdir -p "$ACME_DIR"
echo "OK-LE-$(date +%s)" > "$ACME_FILE"
ok "Criado: $ACME_FILE"

echo "Requisição HTTP direta (sem -L) para ACME:"
curlh "http://$DOMAIN_MAIN/.well-known/acme-challenge/$(basename "$ACME_FILE")" | egrep -i '^HTTP/|^server:|^location:|^content-type:|^content-length:' || true
curl -sS --max-time 12 "http://$DOMAIN_MAIN/.well-known/acme-challenge/$(basename "$ACME_FILE")" | head -n 2 || true

echo
curlh "http://$DOMAIN_WWW/.well-known/acme-challenge/$(basename "$ACME_FILE")" | egrep -i '^HTTP/|^server:|^location:|^content-type:|^content-length:' || true
curl -sS --max-time 12 "http://$DOMAIN_WWW/.well-known/acme-challenge/$(basename "$ACME_FILE")" | head -n 2 || true

section "8) TLS / Certificado em produção"
echo "openssl s_client (issuer/subject) - $DOMAIN_MAIN:"
echo | openssl s_client -connect "${DOMAIN_MAIN}:443" -servername "$DOMAIN_MAIN" 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates || true

echo
echo "openssl s_client (issuer/subject) - $DOMAIN_WWW:"
echo | openssl s_client -connect "${DOMAIN_WWW}:443" -servername "$DOMAIN_WWW" 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates || true

section "9) Certbot / renovação automática"
if command -v certbot >/dev/null 2>&1; then
  echo "certbot certificates:"
  try certbot certificates || true

  echo
  echo "certbot renew --dry-run (pode demorar):"
  try certbot renew --dry-run -v || true

  echo
  echo "certbot.timer:"
  try systemctl status certbot.timer --no-pager || true
  try systemctl list-timers | grep -i certbot || true

  echo
  echo "Renewal hooks deploy (reload lsws):"
  if [ -d /etc/letsencrypt/renewal-hooks/deploy ]; then
    ls -la /etc/letsencrypt/renewal-hooks/deploy || true
    if [ -f /etc/letsencrypt/renewal-hooks/deploy/reload-lsws.sh ]; then
      ok "Hook encontrado: /etc/letsencrypt/renewal-hooks/deploy/reload-lsws.sh"
      echo "Conteúdo:"
      sed -n '1,80p' /etc/letsencrypt/renewal-hooks/deploy/reload-lsws.sh
    else
      warn "Hook reload-lsws.sh não encontrado."
    fi
  else
    warn "Diretório hooks não encontrado."
  fi
else
  warn "certbot não instalado; pulando checks."
fi

section "10) WordPress (arquivos, saúde, URLs, recursos estáticos)"
WP_ROOT="$WEBROOT"
WP_CONFIG="$WP_ROOT/wp-config.php"

if [ -f "$WP_CONFIG" ]; then
  ok "wp-config.php encontrado: $WP_CONFIG"
else
  fail "Não encontrei wp-config.php em $WP_CONFIG (confira WEBROOT=$WEBROOT)"
fi

echo
echo "Permissões básicas (wp-config, wp-content, uploads):"
ls -la "$WP_CONFIG" 2>/dev/null || true
ls -ld "$WP_ROOT/wp-content" 2>/dev/null || true
ls -ld "$WP_ROOT/wp-content/uploads" 2>/dev/null || true

echo
echo "Checando .htaccess (se existir) e regras comuns de loop:"
if [ -f "$WP_ROOT/.htaccess" ]; then
  ok ".htaccess encontrado"
  sed -n '1,220p' "$WP_ROOT/.htaccess" | sed 's/\r$//' || true
  echo
  echo "Linhas suspeitas (redirect / rewrite / HTTPS / www):"
  egrep -n "redirect|rewrite|https|www\.|siteurl|home" "$WP_ROOT/.htaccess" || true
else
  warn ".htaccess não encontrado (normal em OLS com autoLoadHtaccess=1 ainda pode existir; se não, ok)."
fi

echo
echo "Teste de recursos estáticos (imagem/logo/tema) — pegando 1 URL do HTML:"
HTML_TMP="$(mktemp)"
try curl -sS --max-time 15 "https://$DOMAIN_MAIN/" > "$HTML_TMP" || true
ASSET_URL="$(grep -Eo 'https?://[^"]+\.(png|jpg|jpeg|gif|webp|svg|css|js)(\?[^"]*)?' "$HTML_TMP" | head -n 1 || true)"
if [ -n "${ASSET_URL:-}" ]; then
  ok "Asset detectado: $ASSET_URL"
  curl -sS -D- -o /dev/null --max-time 15 "$ASSET_URL" | tr -d '\r' | egrep -i '^(HTTP/|content-type:|content-length:|cache-control:|server:|location:)'
else
  warn "Não consegui extrair automaticamente um asset do HTML (pode ser minificado/JS)."
fi
rm -f "$HTML_TMP" || true

section "11) Banco de dados WordPress (siteurl/home) - opcional"
if [ -f "$WP_CONFIG" ] && command -v php >/dev/null 2>&1; then
  echo "Extraindo credenciais do wp-config.php via PHP (sem imprimir senha):"
  DB_NAME="$(php -r 'include("'"$WP_CONFIG"'"); echo defined("DB_NAME")?DB_NAME:"";' 2>/dev/null || true)"
  DB_USER="$(php -r 'include("'"$WP_CONFIG"'"); echo defined("DB_USER")?DB_USER:"";' 2>/dev/null || true)"
  DB_HOST="$(php -r 'include("'"$WP_CONFIG"'"); echo defined("DB_HOST")?DB_HOST:"";' 2>/dev/null || true)"
  DB_PREFIX="$(php -r 'include("'"$WP_CONFIG"'"); global $table_prefix; echo isset($table_prefix)?$table_prefix:"wp_";' 2>/dev/null || true)"

  echo "DB_NAME=$DB_NAME"
  echo "DB_USER=$DB_USER"
  echo "DB_HOST=$DB_HOST"
  echo "DB_PREFIX=$DB_PREFIX"

  if command -v mysql >/dev/null 2>&1 && [ -n "${DB_NAME:-}" ] && [ -n "${DB_USER:-}" ] && [ -n "${DB_HOST:-}" ]; then
    warn "Para checar siteurl/home via MySQL, você precisa fornecer a senha interativamente."
    echo "Comando sugerido (vai pedir senha):"
    echo "  mysql -h \"$DB_HOST\" -u \"$DB_USER\" -p \"$DB_NAME\" -e \"SELECT option_name, option_value FROM ${DB_PREFIX}options WHERE option_name IN ('siteurl','home');\""
  else
    warn "mysql client ausente ou credenciais não detectadas; pulando query."
  fi
else
  warn "Sem PHP/wp-config, pulando checks DB."
fi

section "12) Diagnóstico rápido (indicadores)"
echo "Se houver ERR_TOO_MANY_REDIRECTS, procure por:"
echo " - WordPress (siteurl/home) divergentes (www vs sem www)"
echo " - Regras de rewrite no LiteSpeed e no WordPress simultaneamente"
echo " - Proxy/CDN ou Apache na frente adicionando redirects extras"
echo
echo "Servidores vistos nos headers agora:"
echo " - http://$DOMAIN_MAIN -> $(curl -sS -I --max-time 12 http://$DOMAIN_MAIN/ | tr -d '\r' | awk -F': ' 'tolower($1)=="server"{print $2; exit}')"
echo " - https://$DOMAIN_MAIN -> $(curl -sS -I --max-time 12 https://$DOMAIN_MAIN/ | tr -d '\r' | awk -F': ' 'tolower($1)=="server"{print $2; exit}')"
echo " - http://$DOMAIN_WWW  -> $(curl -sS -I --max-time 12 http://$DOMAIN_WWW/  | tr -d '\r' | awk -F': ' 'tolower($1)=="server"{print $2; exit}')"
echo " - https://$DOMAIN_WWW -> $(curl -sS -I --max-time 12 https://$DOMAIN_WWW/ | tr -d '\r' | awk -F': 'tolower($1)=="server"{print $2; exit}')"

section "Concluído"
ok "Relatório salvo em: $REPORT"
echo "Se quiser, cole aqui o trecho do relatório das seções 6, 7 e 10 que eu aponto exatamente a origem do redirect/loop/imagens."
