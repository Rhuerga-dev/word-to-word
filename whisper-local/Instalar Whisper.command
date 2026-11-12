#!/bin/zsh
# Whisper local para Word to Word: voz a texto gratis en este Mac (whisper.cpp + large-v3-turbo).
# Lo deja como servicio: arranca solo al encender el Mac y se reinicia si se cae.
# Para quitarlo:  launchctl bootout gui/$(id -u)/dev.huergalabs.whisper
for f in /opt/homebrew/bin /usr/local/bin; do [[ -d "$f" ]] && PATH="$f:$PATH"; done
WS=$(command -v whisper-server)
MODEL="$HOME/Code/whisper-models/ggml-large-v3-turbo-q5_0.bin"
if [[ -z "$WS" ]]; then echo "Falta whisper.cpp:  brew install whisper-cpp"; exit 1; fi
if [[ ! -s "$MODEL" ]]; then
  mkdir -p "${MODEL:h}"
  curl -fL --progress-bar -o "$MODEL.part" "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/${MODEL:t}" && mv "$MODEL.part" "$MODEL" || { echo "No se pudo descargar el modelo."; exit 1; }
fi
LOG="$HOME/Library/Logs/huergalabs"; mkdir -p "$LOG" "$HOME/Library/LaunchAgents"
PLIST="$HOME/Library/LaunchAgents/dev.huergalabs.whisper.plist"
cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>dev.huergalabs.whisper</string>
  <key>ProgramArguments</key><array>
    <string>$WS</string><string>-m</string><string>$MODEL</string>
    <string>-t</string><string>4</string><string>-fa</string><string>-bs</string><string>1</string><string>-bo</string><string>1</string>
    <string>--host</string><string>127.0.0.1</string><string>--port</string><string>8178</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Interactive</string>
  <key>StandardOutPath</key><string>$LOG/whisper.log</string>
  <key>StandardErrorPath</key><string>$LOG/whisper.log</string>
</dict></plist>
PL
launchctl bootout "gui/$(id -u)/dev.huergalabs.whisper" 2>/dev/null
launchctl bootstrap "gui/$(id -u)" "$PLIST" || { echo "No se pudo instalar el servicio."; exit 1; }
for i in {1..60}; do curl -s -o /dev/null http://127.0.0.1:8178/ && { echo "Whisper funcionando en http://127.0.0.1:8178 (arrancó en ${i}s)."; exit 0; }; sleep 1; done
echo "El servicio está instalado pero aún no responde. Mira $LOG/whisper.log"
