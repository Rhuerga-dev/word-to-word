#!/usr/bin/env bash
# Convierte esta carpeta en un proyecto Laravel completo con la app Word to Word.
# Uso (en Terminal, dentro de esta carpeta):   bash setup.sh
set -euo pipefail
cd "$(dirname "$0")"

if [ -f artisan ]; then
  echo "Laravel ya está instalado aquí. Nada que hacer."
  exit 0
fi

command -v composer >/dev/null || { echo "Falta Composer (Herd lo trae: https://herd.laravel.com)"; exit 1; }
command -v php >/dev/null || { echo "Falta PHP (Herd lo trae)"; exit 1; }

echo "1/5 Descargando Laravel…"
composer create-project laravel/laravel _laravel --no-interaction --quiet

echo "2/5 Uniendo Laravel con los archivos de la app…"
# -n: no sobrescribe los archivos de la app (User.php, routes/api.php, etc.)
cp -Rn _laravel/. . || true
rm -rf _laravel

echo "3/5 Instalando la API (Sanctum)…"
cp routes/api.php routes/api.php.app
php artisan install:api --without-migration-prompt --no-interaction
mv -f routes/api.php.app routes/api.php

echo "4/5 Configurando .env…"
if ! grep -q "ANTHROPIC_API_KEY" .env; then
  printf "\n" >> .env
  cat env.additions >> .env
fi

echo "5/5 Base de datos y 156 palabras iniciales…"
php artisan migrate --force
php artisan db:seed --class=WordSeeder --force

echo ""
echo "Listo. Pon tu ANTHROPIC_API_KEY (y AZURE_SPEECH_KEY si la tienes) en .env y luego:"
echo "   php artisan serve"
echo "Abre http://localhost:8000/app/ en Google Chrome."
