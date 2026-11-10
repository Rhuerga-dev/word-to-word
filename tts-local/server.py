#!/usr/bin/env python3
"""Voz local de Word to Word con Kokoro (kokoro-onnx).

Solo escucha en 127.0.0.1: la usa el servidor de Laravel, nunca internet.
  POST /tts  {"text": "...", "lang": "en"|"es", "slow": false}  ->  audio/mpeg
  GET  /health                                                   ->  {"ok": true}
"""
import io
import json
import os
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import lameenc
import numpy as np
from kokoro_onnx import Kokoro

HERE = os.path.dirname(os.path.abspath(__file__))
PORT = int(os.environ.get("KOKORO_PORT", "8880"))
VOICES = {
    "en": (os.environ.get("KOKORO_VOICE_EN", "af_heart"), "en-us"),
    "es": (os.environ.get("KOKORO_VOICE_ES", "ef_dora"), "es"),
}

kokoro = Kokoro(os.path.join(HERE, "kokoro-v1.0.onnx"), os.path.join(HERE, "voices-v1.0.bin"))
lock = threading.Lock()  # un audio a la vez: el Mac tiene 8 GB


def to_mp3(samples, rate):
    pcm = (np.clip(samples, -1.0, 1.0) * 32767).astype(np.int16).tobytes()
    enc = lameenc.Encoder()
    enc.set_bit_rate(64)
    enc.set_in_sample_rate(rate)
    enc.set_channels(1)
    enc.set_quality(2)
    return enc.encode(pcm) + enc.flush()


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, body, ctype="application/json"):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/health":
            return self._send(200, b'{"ok": true}')
        self._send(404, b'{"error": "not found"}')

    def do_POST(self):
        if self.path != "/tts":
            return self._send(404, b'{"error": "not found"}')
        try:
            n = int(self.headers.get("Content-Length", "0"))
            if n > 4000:
                return self._send(413, b'{"error": "too long"}')
            data = json.loads(self.rfile.read(n) or b"{}")
            text = str(data.get("text", "")).strip()[:400]
            if not text:
                return self._send(422, b'{"error": "text"}')
            voice, lang = VOICES["es" if data.get("lang") == "es" else "en"]
            speed = 0.75 if data.get("slow") else 0.95
            with lock:
                samples, rate = kokoro.create(text, voice=voice, speed=speed, lang=lang)
            self._send(200, to_mp3(samples, rate), "audio/mpeg")
        except Exception as e:  # noqa: BLE001
            print("error:", e, file=sys.stderr)
            self._send(500, b'{"error": "tts"}')

    def log_message(self, fmt, *args):  # sin ruido en la consola
        pass


if __name__ == "__main__":
    print(f"Voz local Kokoro en http://127.0.0.1:{PORT}  (Ctrl+C para parar)")
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
