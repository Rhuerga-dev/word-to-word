#!/usr/bin/env bash
# Abre Word to Word en el iPhone a través de un túnel HTTPS de Cloudflare.
# Uso:  bash tunnel.sh          (usa el puerto 8002)
#       bash tunnel.sh 8003     (otro puerto)
set -euo pipefail
cd "$(dirname "$0")"
PORT="${1:-8002}"

command -v cloudflared >/dev/null || { echo "Falta cloudflared:  brew install cloudflared"; exit 1; }

# Arranca Laravel si no está corriendo en ese puerto
if ! lsof -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Arrancando Laravel en el puerto $PORT…"
  php artisan serve --port="$PORT" >/dev/null 2>&1 &
  LARAVEL_PID=$!
  trap 'kill $LARAVEL_PID 2>/dev/null || true' EXIT
  sleep 2
fi

echo ""
echo "Busca abajo la línea con  https://….trycloudflare.com"
echo "En el iPhone: abre esa dirección + /app/ en Safari → Compartir → Agregar a pantalla de inicio."
echo "Ctrl+C para cerrar el túnel."
echo ""
cloudflared tunnel --url "http://localhost:$PORT"
