#!/bin/bash
# Voz local Kokoro para Word to Word. La primera vez instala todo (unos 400 MB) y luego solo arranca.
cd "$(dirname "$0")" || exit 1

PY=$(command -v python3.12 || command -v python3.11 || command -v python3.13 || command -v python3.10 || command -v python3)
VER=$("$PY" -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null)
case "$VER" in 3.10|3.11|3.12|3.13) ;; *)
  echo "Hace falta Python 3.10 a 3.13 (tienes: ${VER:-ninguno})."
  echo "Instálalo con:  brew install python@3.12   y vuelve a abrir este archivo."
  read -r -p "Pulsa Enter para cerrar"; exit 1 ;;
esac

if [ ! -d .venv ]; then
  echo "Instalando la voz local (solo la primera vez)…"
  "$PY" -m venv .venv && .venv/bin/pip install --upgrade pip -q && .venv/bin/pip install -q "kokoro-onnx>=0.4" lameenc numpy || { echo "No se pudo instalar."; read -r -p "Enter para cerrar"; exit 1; }
fi

BASE="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0"
for f in kokoro-v1.0.onnx voices-v1.0.bin; do
  if [ ! -s "$f" ]; then
    echo "Descargando $f…"
    curl -fL --progress-bar -o "$f.part" "$BASE/$f" && mv "$f.part" "$f" || { echo "No se pudo descargar $f."; read -r -p "Enter para cerrar"; exit 1; }
  fi
done

exec .venv/bin/python server.py
