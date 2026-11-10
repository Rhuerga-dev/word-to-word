# Voz local (Kokoro)

Voz natural que corre en tu Mac, sin internet y sin pagar a Azure.

1. Doble clic en **Arrancar voz local.command** (la primera vez instala ~400 MB).
2. Deja la ventana abierta. Word to Word la usa sola; si está apagada, vuelve a Azure.

- Solo escucha en `127.0.0.1:8880` (nunca desde internet).
- Voces: `KOKORO_VOICE_EN` (por defecto `af_heart`) y `KOKORO_VOICE_ES` (`ef_dora`).
- En Ajustes → «Comparar voces» oyes la misma frase con Azure y con Kokoro.
- Para usar solo Azure: pon `KOKORO_URL=` (vacío) en el `.env`.
