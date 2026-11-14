// Word to Word · Arranque. Va el último: así todos los archivos (app, manos libres, taller, hoy…)
// ya están cargados cuando la app empieza a usarlos.

// ===== Arranque =====
(function boot() {
  const qs = new URLSearchParams(location.search);
  const clean = () => { try { history.replaceState(null, "", location.pathname); } catch (e) {} };
  if (qs.get("reset") && qs.get("email")) {
    resetToken = qs.get("reset"); clean();
    showAuth(); setAuthMode("reset"); $("aEmail").value = qs.get("email"); $("aPass").focus();
    return;
  }
  // huergalabs.dev enlaza aquí con ?demo=1 ("Probar demo").
  if (qs.get("demo") === "1") { clean(); if (!token) { showAuth(); setAuthMode("login"); startDemo(); return; } }
  const verified = qs.get("verified") === "1"; if (verified) clean();
  setAuthMode("login");
  if (token) {
    start().then(() => { if (verified) renderBanners('<div class="banner ok"><p>¡Listo! Tu correo quedó confirmado.</p></div>'); });
  } else {
    showAuth();
    if (verified) $("authOk").textContent = "¡Listo! Tu correo quedó confirmado. Ya puedes entrar.";
  }
})();
