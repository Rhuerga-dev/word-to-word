// Service worker de Word to Word: guarda la "cáscara" de la app para que abra rápido.
// La API (/api/...) nunca se guarda en caché: siempre va a la red.
const CACHE = "wtw-shell-v33";
const SHELL = [
  "/app/",
  "/app/i18n.js?v=5",
  "/app/app.js?v=14",
  "/app/speak.js?v=10",
  "/app/progress.js?v=4",
  "/app/today.js?v=6",
  "/app/mictest.js?v=3",
  "/app/manifest.webmanifest",
  "/app/icons/apple-touch-icon.png?v=2",
  "/app/icons/icon-192.png?v=2",
  "/app/icons/icon-512.png?v=2",
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
        .then((res) => { if (res.ok && url.pathname.startsWith("/app")) { const copy = res.clone(); caches.open(CACHE).then((c) => c.put("/app/", copy)); } return res; })
        .catch(() => caches.match("/app/"))
    );
    return;
  }

  if (url.origin !== location.origin) return;

  // El código de la app (app.js, manifest): primero la red, para que nunca se mezcle una página nueva
  // con un app.js viejo; sin conexión, la copia guardada.
  if (/\.(js|webmanifest)$/.test(url.pathname)) {
    e.respondWith(
      fetch(e.request)
        .then((res) => { if (res.ok) { const copy = res.clone(); caches.open(CACHE).then((c) => c.put(e.request, copy)); } return res; })
        .catch(() => caches.match(e.request))
    );
    return;
  }

  // Íconos y demás archivos fijos: primero la caché.
  e.respondWith(caches.match(e.request).then((hit) => hit || fetch(e.request)));
});

// ===== Recordatorios (notificaciones push) =====
self.addEventListener("push", (e) => {
  let data = {};
  try { data = e.data ? e.data.json() : {}; } catch (err) { data = { title: "W2W", body: e.data ? e.data.text() : "" }; }
  const title = data.title || "Hora de practicar inglés";
  e.waitUntil(self.registration.showNotification(title, {
    body: data.body || "Abre W2W y practica unos minutos.",
    icon: data.icon || "/app/icons/icon-192.png?v=2",
    badge: data.badge || "/app/icons/icon-192.png?v=2",
    tag: data.tag || "daily-reminder",
    data: data.data || { url: "/app/" },
  }));
});

self.addEventListener("notificationclick", (e) => {
  e.notification.close();
  const url = (e.notification.data && e.notification.data.url) || "/app/";
  e.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((wins) => {
      const open = wins.find((w) => new URL(w.url).pathname.startsWith("/app"));
      return open ? open.focus() : self.clients.openWindow(url);
    })
  );
});
