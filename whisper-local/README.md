# Whisper local (voz a texto gratis)

Word to Word pasa la voz a texto con Whisper en este Mac (whisper.cpp, modelo large-v3-turbo) y, si no
responde, con Azure. La evaluación de pronunciación sigue en Azure.

1. `brew install whisper-cpp` (una vez).
2. Doble clic en **Instalar Whisper.command**: baja el modelo (~550 MB) y lo deja como servicio que arranca
   con el Mac y se reinicia si se cae. Solo escucha en `127.0.0.1:8178`, nunca desde internet.
3. En el `.env`: `WHISPER_URL=http://127.0.0.1:8178`. Sin esa línea, todo va a Azure como antes.

- Registro: `~/Library/Logs/huergalabs/whisper.log`.
- Quitarlo: `launchctl bootout gui/$(id -u)/dev.huergalabs.whisper` y borra `WHISPER_URL` del `.env`.
- Comparar con Azure: `php artisan speech:compare <carpeta con wav>`.
- Usa ~630 MB de memoria. Si Whisper falla, la app espera un minuto antes de volver a probarlo.
