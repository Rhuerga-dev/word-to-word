/* Ajustes → «Qué aprendes» (elegir curso) y «Tu trabajo» (profesión y para qué quieres el inglés), como en la app.
   También la tarjeta «¿A qué te dedicas?» de Hoy mientras no hayas elegido profesión.
   API: GET /courses, PUT /course {code}; GET /professions, PUT /profile {profession, goal}.
   Sin atributos de evento en el HTML (CSP): los botones llevan data-acct="…" y aquí se escuchan. */
"use strict";
(function () {
  const acct = { courses: null, prof: null, picking: false, sel: { profession: null, goal: null }, msg: "", busy: false };
  const FLAG = { en: "🇺🇸", es: "🇪🇸" };

  // ---------- Qué aprendes ----------
  async function loadCourses() {
    try { acct.courses = await api("/courses"); } catch (e) { acct.courses = null; }
    renderCourses();
  }
  function renderCourses() {
    const box = $("courseBox"); if (!box) return;
    const list = acct.courses && acct.courses.courses || [];
    // Solo si hay de verdad algo que elegir (como en la app).
    box.hidden = list.length < 2;
    if (box.hidden) { box.innerHTML = ""; return; }
    box.innerHTML = `<h3 class="acct-h">Qué aprendes</h3>
      <div class="acct-list" role="radiogroup" aria-label="Qué aprendes">
        ${list.map(c => `<button type="button" class="acct-opt${c.current ? " on" : ""}" role="radio" aria-checked="${c.current}" data-acct="course" data-code="${esc(c.code)}"${acct.busy ? " disabled" : ""}>
          <span class="acct-flag" aria-hidden="true">${FLAG[c.learn] || "🌐"}</span>
          <span class="acct-txt"><b>${esc(c.name)}</b>${c.active ? "" : `<small>En construcción (solo para probar)</small>`}</span>
          ${c.current ? `<span class="acct-ok" aria-hidden="true">✓</span>` : ""}</button>`).join("")}
      </div>
      <p class="note" aria-live="polite">${esc(acct.msg || "Cada curso guarda su progreso aparte: al cambiar no pierdes nada.")}</p>`;
  }
  async function setCourse(code) {
    const cur = (acct.courses.courses || []).find(c => c.current);
    if (acct.busy || (cur && cur.code === code)) return;
    acct.busy = true; acct.msg = "Cambiando de curso…"; renderCourses();
    try {
      await api("/course", { method: "PUT", body: { code } });
      // Cambia todo (palabras, unidades, idioma de la pantalla): se vuelve a cargar la app entera.
      location.reload();
    } catch (e) {
      acct.busy = false; acct.msg = "No se pudo cambiar de curso. Inténtalo otra vez."; renderCourses();
    }
  }

  // ---------- Tu trabajo ----------
  async function loadProfessions() {
    if (acct.prof) return acct.prof;
    try { acct.prof = await api("/professions"); } catch (e) { acct.prof = null; }
    return acct.prof;
  }
  function labelOf(list, id) { const x = (list || []).find(p => p.id === id); return x ? x : null; }
  function renderProfession() {
    const box = $("profBox"); if (!box) return;
    const demo = !!(profile && profile.demo);
    box.hidden = demo || !profile; if (box.hidden) return;
    const cur = acct.prof ? labelOf(acct.prof.professions, profile.profession) : null;
    if (!acct.picking) {
      box.innerHTML = `<h3 class="acct-h">${profile.profession ? "Tu trabajo" : "¿A qué te dedicas?"}</h3>
        <button type="button" class="acct-opt" data-acct="prof-open">
          <span class="acct-flag" aria-hidden="true">${cur ? esc(cur.emoji) : "💼"}</span>
          <span class="acct-txt"><b>${profile.profession ? esc(cur ? cur.label : "Cambiar") : "Elige tu profesión"}</b>
          <small>${profile.profession ? "Cambiar" : "La app practicará situaciones de tu trabajo."}</small></span></button>`;
      return;
    }
    const P = acct.prof;
    if (!P) { box.innerHTML = `<p class="warnbox">No se pudo cargar la lista. Inténtalo otra vez.</p><div class="row"><button type="button" data-acct="prof-close">Cerrar</button></div>`; return; }
    box.innerHTML = `<h3 class="acct-h">¿A qué te dedicas?</h3>
      <p class="note">Las conversaciones y los temas se adaptan a tu trabajo.</p>
      <div class="acct-chips" role="radiogroup" aria-label="Tu profesión">
        ${P.professions.map(p => `<button type="button" class="chip${acct.sel.profession === p.id ? " on" : ""}" role="radio" aria-checked="${acct.sel.profession === p.id}" data-acct="pick-prof" data-id="${esc(p.id)}">${esc(p.emoji)} ${esc(p.label)}</button>`).join("")}
      </div>
      <b>¿Para qué quieres el inglés?</b>
      <div class="acct-chips" role="radiogroup" aria-label="Para qué quieres el inglés">
        ${P.goals.map(g => `<button type="button" class="chip${acct.sel.goal === g.id ? " on" : ""}" role="radio" aria-checked="${acct.sel.goal === g.id}" data-acct="pick-goal" data-id="${esc(g.id)}">${esc(g.label)}</button>`).join("")}
      </div>
      <div class="row"><button type="button" class="primary" data-acct="prof-save"${acct.busy || !acct.sel.profession ? " disabled" : ""}>${acct.busy ? "Guardando…" : "Guardar"}</button>
        <button type="button" data-acct="prof-close">Cancelar</button></div>
      <p class="note" aria-live="polite">${esc(acct.msg)}</p>`;
  }
  async function openPicker() {
    acct.picking = true; acct.msg = "";
    acct.sel = { profession: profile.profession || null, goal: profile.goal || null };
    await loadProfessions();
    renderProfession();
    const box = $("profBox"); if (box && box.scrollIntoView) box.scrollIntoView({ block: "start", behavior: "smooth" });
  }
  async function saveProfession() {
    if (!acct.sel.profession || acct.busy) return;
    acct.busy = true; acct.msg = ""; renderProfession();
    try {
      profile = await api("/profile", { method: "PUT", body: { profession: acct.sel.profession, goal: acct.sel.goal } });
      acct.picking = false;
      if (typeof refresh === "function") refresh();
      if (typeof td !== "undefined" && td.data && typeof tdRender === "function") tdRender();
    } catch (e) { acct.msg = e.message; }
    acct.busy = false; renderProfession();
  }

  document.addEventListener("click", e => {
    const b = e.target.closest("[data-acct]"); if (!b) return;
    const k = b.dataset.acct;
    if (k === "course") setCourse(b.dataset.code);
    else if (k === "prof-open") openPicker();
    else if (k === "prof-close") { acct.picking = false; acct.msg = ""; renderProfession(); }
    else if (k === "pick-prof") { acct.sel.profession = b.dataset.id; renderProfession(); }
    else if (k === "pick-goal") { acct.sel.goal = acct.sel.goal === b.dataset.id ? null : b.dataset.id; renderProfession(); }
    else if (k === "prof-save") saveProfession();
    else if (k === "today-prof") { if (typeof showTab === "function") showTab("settings"); openPicker(); }
  });

  /** Lo llama renderSettings(). */
  window.acctRender = function () {
    if (!acct.courses) loadCourses(); else renderCourses();
    if (!acct.prof && profile && profile.profession) loadProfessions().then(renderProfession);
    renderProfession();
  };

  /** Tarjeta de Hoy: «¿A qué te dedicas?» mientras no haya profesión (no en la demo). */
  window.acctTodayCard = function () {
    if (!profile || profile.demo || profile.profession) return "";
    return `<button type="button" class="td-link" data-acct="today-prof"><span class="ic" aria-hidden="true">💼</span>
      <span style="flex:1;display:grid;gap:4px"><b>¿A qué te dedicas?</b><small class="note">Elige tu profesión y la app practicará situaciones de tu trabajo.</small></span></button>`;
  };
})();
