# Voz local (Kokoro)

Voz natural que corre en tu Mac, sin internet y sin pagar a Azure.

Es opcional: por defecto Word to Word usa la voz de Azure.

1. Pon `KOKORO_URL=http://127.0.0.1:8880` en el `.env` de Word to Word.
2. Doble clic en **Arrancar voz local.command** (la primera vez instala ~400 MB).
3. Deja la ventana abierta. Word to Word la usa sola; si está apagada, vuelve a Azure.

- Solo escucha en `127.0.0.1:8880` (nunca desde internet).
- Voces: `KOKORO_VOICE_EN` (por defecto `af_heart`) y `KOKORO_VOICE_ES` (`ef_dora`).
- En Ajustes → «Comparar voces» oyes la misma frase con Azure y con Kokoro.
- Para volver a solo Azure: quita `KOKORO_URL` del `.env`.
