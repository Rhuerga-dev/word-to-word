/* Ajustes → «💡 Enviar sugerencia» y el enlace «☕ Apoya mi desarrollo con un café».
   Sin onclick= en el HTML: los botones llevan data-fb="…" y aquí se escuchan (así lo exige la CSP).
   La sugerencia va a POST /api/suggestions con la plataforma, la versión de la web y la pantalla;
   el servidor sabe quién eres por tu sesión, no por lo que mande esta página. */
(function () {
  const box = $("fbBox"), text = $("fbText"), msg = $("fbMsg"), send = $("fbSend");
  if (!box) return;

  // Versión de la web: el ?v= de app.js (cambia en cada publicación).
  function webVersion() {
    const s = document.querySelector('script[src*="/app/app.js"]');
    const v = s ? (new URL(s.src, location.href)).searchParams.get("v") : null;
    return "web" + (v ? "-" + v : "");
  }
  function say(t, ok) { msg.textContent = t; msg.style.color = ok ? "var(--good)" : ""; }
  function open(yes) { box.hidden = !yes; say(""); if (yes) text.focus(); }

  async function submit() {
    const message = text.value.trim();
    if (message.length < 5) { say("Escribe un poco más."); return; }
    send.disabled = true; say("Enviando…");
    try {
      await api("/suggestions", { method: "POST", body: { type: $("fbType").value, message, platform: "web", app_version: webVersion(), screen: "settings" } });
      text.value = ""; say("¡Gracias! Recibimos tu sugerencia.", true);
    } catch (e) { say(e.message); }
    send.disabled = false;
  }

  document.addEventListener("click", e => {
    const b = e.target.closest("[data-fb]"); if (!b) return;
    if (b.dataset.fb === "open") open(box.hidden);
    else if (b.dataset.fb === "cancel") open(false);
    else if (b.dataset.fb === "send") submit();
  });

  /** Lo llama renderSettings(): la demo no envía sugerencias y el enlace de apoyo solo sale si está configurado. */
  window.fbRender = function () {
    const demo = !!(typeof profile !== "undefined" && profile && profile.demo);
    $("fbRow").hidden = demo; if (demo) box.hidden = true;
    $("supportLink").hidden = !(typeof cfg !== "undefined" && cfg && cfg.support);
  };
})();
