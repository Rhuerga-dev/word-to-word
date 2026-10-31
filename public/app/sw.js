// Service worker de Word to Word: guarda la "cáscara" de la app para que abra rápido.
// La API (/api/...) nunca se guarda en caché: siempre va a la red.
const CACHE = "wtw-shell-v2";
const SHELL = [
  "/app/",
  "/app/manifest.webmanifest",
  "/app/icons/apple-touch-icon.png",
  "/app/icons/icon-192.png",
  "/app/icons/icon-512.png",
];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (e) => {
  const url = new URL(e.request.url);
  if (e.request.method !== "GET" || url.pathname.startsWith("/api/")) return;

  // La página: primero la red (para ver cambios al instante), si no hay conexión, la copia guardada.
  if (e.request.mode === "navigate") {
    e.respondWith(
      fetch(e.request)
        .then((res) => { caches.open(CACHE).then((c) => c.put("/app/", res.clone())); return res; })
        .catch(() => caches.match("/app/"))
    );
    return;
  }

  // Íconos y archivos fijos: primero la caché.
  if (url.origin === location.origin) {
    e.respondWith(caches.match(e.request).then((hit) => hit || fetch(e.request)));
  }
});
