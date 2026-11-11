// Borrar la cuenta sin la app (Google Play pide que se pueda desde una web).
document.getElementById("del").addEventListener("submit", async e => {
  e.preventDefault();
  const msg = document.getElementById("msg"), go = document.getElementById("go");
  if (!confirm("¿Seguro? Se borra todo y no se puede deshacer.")) return;
  go.disabled = true; msg.className = "msg"; msg.textContent = "Borrando…";
  try {
    const r = await fetch("/api/account/delete", {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({ email: document.getElementById("email").value, password: document.getElementById("password").value }),
    });
    const d = await r.json().catch(() => ({}));
    if (r.ok) {
      msg.className = "msg ok"; msg.textContent = "Listo: tu cuenta y todos sus datos se borraron.";
      e.target.reset();
      return;
    }
    const first = d.errors ? Object.values(d.errors)[0][0] : d.message;
    msg.className = "msg bad"; msg.textContent = r.status === 429 ? "Demasiados intentos. Espera un minuto." : (first || "No se pudo borrar.");
  } catch (err) {
    msg.className = "msg bad"; msg.textContent = "Sin conexión. Prueba otra vez.";
  }
  go.disabled = false;
});
