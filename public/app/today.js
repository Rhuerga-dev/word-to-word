/* Word to Word · Hoy, Practicar, Camino y la sesión guiada (fase 1).
   "Hoy" decide por ti: un botón y unos 10 minutos mezclando fichas, tu sonido débil, hablar y tus errores.
   Usa la API: GET /session/today, POST /session/complete (y las de fichas, pronunciación y hablar). */
"use strict";

const td = { data: null, error: "" };
const SVG = {
  fire: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 2c1 4 5 5.5 5 11a5 5 0 0 1-10 0c0-2.5 1.2-4 2.5-5.2.2 1.8 1 3 2.2 3.4C11 8.6 11 5 12 2z" fill="#e8790c"/></svg>',
  bolt: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M13 2 4 14h7l-1 8 9-12h-7z"/></svg>',
  play: '<svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M7 4v16l13-8z"/></svg>',
  check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m5 12 5 5 9-10"/></svg>',
  mic: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="9" y="3" width="6" height="11" rx="3" fill="currentColor"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/></svg>',
  map: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 4 3 6v14l6-2 6 2 6-2V4l-6 2z"/><path d="M9 4v14M15 6v14"/></svg>',
};
const SPEAK_LABEL = { narrate: ["Hablar 1 min", "narración del día"], picture: ["Hablar 45 s", "describe una foto"], shadowing: ["Shadowing", "repite como un nativo"] };

// ---------- Hoy ----------
async function tdOpen() {
  const el = $("todayView"); if (!el) return;
  if (!td.data) el.innerHTML = '<p class="note">Cargando tu día…</p>';
  try {
    const [t, p] = await Promise.all([api("/session/today"), api("/path").catch(() => null)]);
    td.data = t; if (p) pth.data = p; td.error = "";
  } catch (e) { td.error = e.message; }
  tdRender();
}

function tdSound(plan) {
  return (plan.sounds || []).find(s => typeof DRILLS !== "undefined" && DRILLS[labKey(s.phoneme)]) || null;
}

function tdRender() {
  const el = $("todayView"); if (!el) return;
  const d = td.data;
  if (!d) { el.innerHTML = `<p class="warnbox">${esc(td.error || "No se pudo cargar tu día.")}</p>`; return; }
  const x = d.xp, p = d.plan, pct = Math.min(1, x.xp / x.goal), C = 2 * Math.PI * 31;
  const sound = tdSound(p), sp1 = SPEAK_LABEL[p.speak] || SPEAK_LABEL.narrate;
  const name = typeof firstName === "function" ? firstName() : "";
  const left = Math.max(0, x.goal - x.xp);
  const empty = !p.reviews.length && !p.new.length && !sound && !p.mistakes.length;
  el.innerHTML = `
    <div class="td-top"><div></div>
      <div class="td-chips"><span class="td-chip xp" title="Puntos en total">${SVG.bolt}${x.total} XP</span></div></div>
    ${td.error ? `<p class="warnbox">${esc(td.error)}</p>` : ""}
    <div class="td-goal">
      <svg width="76" height="76" viewBox="0 0 76 76" role="img" aria-label="Meta del día: ${x.xp} de ${x.goal} XP">
        <circle cx="38" cy="38" r="31" fill="none" stroke="var(--line)" stroke-width="9"/>
        <circle cx="38" cy="38" r="31" fill="none" stroke="var(--good)" stroke-width="9" stroke-linecap="round" stroke-dasharray="${(C * pct).toFixed(1)} ${C.toFixed(1)}" transform="rotate(-90 38 38)"/>
      </svg>
      <div><span>${esc(greeting())}${name ? ", " + esc(name) : ""}</span><b>${x.xp} de ${x.goal} XP</b><span>${left ? `Te faltan ${left} XP para tu meta de hoy` : "¡Meta de hoy cumplida! 🎉"}</span></div>
    </div>
    <section class="td-card" aria-labelledby="tdTitle">
      <h2 id="tdTitle">${x.sessions ? "Otra ronda" : "Sesión de hoy"} <small>unos 10 min</small></h2>
      <div class="td-steps">
        ${(p.ear || []).length ? `<div class="td-step"><b>Oído · ${p.ear.length} ${p.ear.length === 1 ? "palabra" : "palabras"}</b><span>reconócelas al oírlas</span></div>` : ""}
        ${p.reviews.length || p.new.length ? `<div class="td-step"><b>${p.reviews.length + p.new.length} fichas</b><span>${p.reviews.length} repasos · ${p.new.length} nuevas</span></div>` : `<div class="td-step done"><b>Fichas</b><span>al día</span></div>`}
        ${sound ? `<div class="td-step"><b>Sonido /${esc(sound.phoneme)}/</b><span>tu más débil</span></div>` : `<div class="td-step"><b>Pronunciación</b><span>una palabra difícil</span></div>`}
        <div class="td-step"><b>${esc(sp1[0])}</b><span>${esc(sp1[1])}</span></div>
        ${p.mistakes.length ? `<div class="td-step"><b>${p.mistakes.length} ${p.mistakes.length === 1 ? "error" : "errores"}</b><span>dilos bien</span></div>` : `<div class="td-step done"><b>Errores</b><span>ninguno pendiente</span></div>`}
      </div>
      <button type="button" class="td-go" id="tdGo">${SVG.play}${x.sessions ? "Otra ronda" : "Empezar"}</button>
    </section>
    ${tdPathLink()}
    <div class="td-row">
      <div class="td-mini"><span>Hablaste hoy</span><b>${String(d.minutes).replace(".", ",")} min</b></div>
      <div class="td-mini"><span>Esta semana</span><b>${x.week.reduce((a, w) => a + w.xp, 0)} XP</b></div>
    </div>`;
  $("tdGo").onclick = () => sessStart();
  if ($("tdPath")) $("tdPath").onclick = () => showTab("path");
  if (empty) $("tdGo").title = "Hoy no hay pendientes: la sesión será de pronunciación y hablar.";
}

function tdPathLink() {
  const d = pth.data; if (!d || !d.units || !d.units.length) return "";
  const u = d.units.find(x => x.id === d.current);
  const n = u ? ["words", "sound", "shadow", "test"].filter(k => u.steps[k]).length : 4;
  return `<button type="button" class="td-link" id="tdPath"><span class="ic">${u ? uIcon(u.icon) : SVG.check}</span>
    <span style="flex:1;display:grid;gap:4px"><small class="note">Camino ${esc(d.level)} · ${u ? "Unidad " + u.number : "completo"}</small><b>${u ? esc(u.title) : "¡Todas las unidades hechas!"}</b>
    <span class="sp-bar"><i style="width:${Math.round(n / 4 * 100)}%"></i></span></span></button>`;
}

// ---------- Practicar ----------
function prOpen() {
  const el = $("practiceBody"); if (!el) return;
  const T = (id, icon, title, sub) => `<button type="button" class="pr-tile" id="${id}">${icon}<b>${title}</b><small>${sub}</small></button>`;
  const I = p => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${p}</svg>`;
  el.innerHTML = `<div class="kind"><span>Practicar</span><span>todo suma puntos</span></div>
    <p class="note">Elige tú qué hacer.</p>
    <div class="pr-tiles">
      ${T("prSpeak", I('<path d="M21 12a8 8 0 0 1-11.6 7.1L4 20l1-4.6A8 8 0 1 1 21 12z"/>'), "Hablar", "conversación, narración, foto, shadowing")}
      ${T("prCards", I('<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M7 9h10M7 13h6"/>'), "Fichas", "repasos y palabras nuevas")}
      ${T("prLab", I('<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.5"/>'), "Taller de pronunciación", "sonido por sonido")}
      ${T("prChat", I('<path d="M4 5h16v10H8l-4 4z"/>'), "Chat escrito", "conversación escribiendo")}
    </div>`;
  $("prSpeak").onclick = () => showTab("speak");
  $("prCards").onclick = () => showTab("cards");
  $("prLab").onclick = () => { unlockAudio(); lab.returnTo = null; openLab(); };
  $("prChat").onclick = () => showTab("chat");
}

// ---------- Camino ----------
const pth = { data: null, error: "" };
const UNIT_ICON = {
  briefcase: '<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>',
  heart: '<path d="M12 20s-7-4.4-9-9a5 5 0 0 1 9-3 5 5 0 0 1 9 3c-2 4.6-9 9-9 9z"/>',
  plane: '<path d="M10 14 3 11l2-2 7 1 5-5a2 2 0 0 1 3 3l-5 5 1 7-2 2-3-7-3 3v3l-2 1-1-4-4-1 1-2h3z"/>',
  card: '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 10h18"/>',
  rocket: '<path d="M5 15c-1 1-1 4-1 4s3 0 4-1M9 15l-3-3c1-4 5-9 12-9 0 7-5 11-9 12z"/><circle cx="14.5" cy="9.5" r="1.5"/>',
  user: '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
  chat: '<path d="M21 12a8 8 0 0 1-11.6 7.1L4 20l1-4.6A8 8 0 1 1 21 12z"/>',
  code: '<path d="m8 8-5 4 5 4M16 8l5 4-5 4M14 4l-4 16"/>',
  phone: '<path d="M5 3h4l2 5-3 2a11 11 0 0 0 6 6l2-3 5 2v4a2 2 0 0 1-2 2A17 17 0 0 1 3 5a2 2 0 0 1 2-2z"/>',
  home: '<path d="M3 11 12 4l9 7v9a1 1 0 0 1-1 1h-5v-6h-6v6H4a1 1 0 0 1-1-1z"/>',
};
const uIcon = k => `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${UNIT_ICON[k] || UNIT_ICON.chat}</svg>`;
const LOCK = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></svg>';

async function pathOpen() {
  const el = $("pathBody"); if (!el) return;
  if (!pth.data) el.innerHTML = '<p class="note">Cargando tu camino…</p>';
  try { pth.data = await api("/path"); pth.error = ""; } catch (e) { pth.error = e.message; }
  pathRender();
}

function pathRender() {
  const el = $("pathBody"); if (!el) return;
  const d = pth.data;
  if (!d) { el.innerHTML = `<p class="warnbox">${esc(pth.error || "No se pudo cargar el camino.")}</p>`; return; }
  if (!d.units.length) { el.innerHTML = `<div class="kind"><span>Camino</span></div><p class="note">Todavía no hay unidades para tu nivel.</p>`; return; }
  const cur = d.units.find(u => u.id === d.current);
  let html = `<div class="kind"><span>Tu camino · ${esc(d.level)} ${esc(d.level_name || "")}</span><span>${d.completed} de ${d.units.length}</span></div>`;
  if (pth.error) html += `<p class="warnbox">${esc(pth.error)}</p>`;
  if (!cur) html += `<p class="banner ok">🏆 ¡Completaste todas las unidades de ${esc(d.level)}! Es buen momento para el examen de nivel (en Progreso).</p>`;
  html += `<div class="pth-list">${d.units.map(u => u.id === d.current ? pathCurrent(u) : pathRow(u)).join("")}</div>`;
  el.innerHTML = html;
  el.querySelectorAll("[data-pth]").forEach(b => b.onclick = () => pathAction(b.dataset.pth, b.dataset.unit));
}

function pathRow(u) {
  const done = u.state === "done";
  return `<div class="pth-row ${u.state}">
    <span class="pth-dot">${done ? SVG.check : u.state === "locked" ? LOCK : uIcon(u.icon)}</span>
    <span style="flex:1;display:grid;gap:1px"><b>${u.number} · ${esc(u.title)}</b><small class="note">${done ? `Completada${u.test.score != null ? " · prueba " + u.test.score + "/10" : ""}` : u.state === "locked" ? "Se abre al pasar la unidad anterior" : "Abierta"}</small></span>
  </div>`;
}

function pathCurrent(u) {
  const st = u.steps, k = (key, ok, title, sub, btn, locked) => `<div class="pth-step${ok ? " ok" : ""}${locked ? " locked" : ""}">
      <span class="pth-sdot">${ok ? SVG.check : locked ? LOCK : ""}</span>
      <span style="flex:1;display:grid;gap:1px"><b>${title}</b><small class="note">${sub}</small></span>
      ${!ok && !locked && btn ? `<button type="button" class="${key === "test" ? "primary" : ""}" data-pth="${key}" data-unit="${esc(u.id)}">${btn}</button>` : ""}</div>`;
  const doneN = ["words", "sound", "shadow", "test"].filter(x => st[x]).length;
  return `<section class="pth-cur" aria-label="Unidad actual">
    <div class="pth-head"><span class="pth-dot cur">${uIcon(u.icon)}</span><span style="flex:1"><small class="note">Unidad ${u.number}</small><h3>${esc(u.title)}</h3></span><span class="chip">${doneN} de 4</span></div>
    ${k("words", st.words, "Palabras", `${u.words.learned} de ${u.words.need} · ${esc(u.words.preview.join(", "))}`, "Aprender")}
    ${k("sound", st.sound, `Sonido /${esc(u.sound)}/`, "un taller aprobado", "Taller")}
    ${k("shadow", st.shadow, "Shadowing", "repite un diálogo del tema", "Empezar")}
    ${k("test", st.test, "Prueba: " + esc(u.scenario_title || "conversación"), u.test_ready ? (u.test.tries ? `Mejor nota ${u.test.score ?? "—"}/10 · aprueba con 6` : "una conversación real con la IA, aprueba con 6/10") : "se abre al terminar los otros 3 pasos", "Hacer la prueba", !u.test_ready)}
    ${u.test.feedback && !st.test ? `<p class="note">Última prueba: ${esc(u.test.feedback)} ${esTranslate(u.test.feedback)}</p>` : ""}
  </section>`;
}

async function pathAction(step, unitId) {
  unlockAudio();
  const u = pth.data.units.find(x => x.id === unitId); if (!u) return;
  if (step === "words") {
    let cards = [];
    try { cards = (await api(`/path/units/${unitId}/words`)).cards; } catch (e) { pth.error = e.message; return pathRender(); }
    if (!cards.length) { pth.error = "No hay palabras nuevas listas para esta unidad todavía."; return pathRender(); }
    return sessRun(cards.map(c => ({ type: "new", card: c })), { title: u.title, onEnd: () => showTab("path") });
  }
  if (step === "sound") { lab.returnTo = "path"; return openLab(u.sound); }
  if (step === "shadow") return sessRun([{ type: "speak", mode: "shadowing", unit: unitId }], { title: u.title, onEnd: () => showTab("path") });
  if (step === "test") {
    showTab("speak");
    sp.unitTest = unitId;
    if (!sp.scenarios) { try { sp.scenarios = (await api("/speaking/scenarios")).scenarios; } catch (e) {} }
    spStart(u.scenario);
  }
}

// ---------- Sesión guiada ----------
const sess = { steps: [], i: 0, total: 0, done: 0, xp0: 0, gained: 0, right: 0, graded: 0, t0: 0 };

// Sesión con pasos dados (p. ej. las palabras de una unidad del Camino). onEnd: a dónde volver.
function sessRun(steps, opts) {
  unlockAudio();
  if (hf.on) stopHF(true);
  Object.assign(sess, { steps, i: -1, total: steps.length, done: 0, xp0: 0, gained: 0, right: 0, graded: 0, t0: Date.now(), custom: opts || {} });
  $("speakBody").innerHTML = "";
  $("sessionView").hidden = false; document.body.style.overflow = "hidden";
  $("sessClose").onclick = sessQuit;
  sessNext();
}

async function sessStart() {
  unlockAudio();
  if (hf.on) stopHF(true);
  sess.custom = null;
  let d = td.data;
  try { d = td.data = await api("/session/today"); } catch (e) { if (!d) { td.error = e.message; return tdRender(); } }
  const p = d.plan, steps = [];
  // Primero el oído, con la cabeza fresca: reconocer al escuchar, sin texto y sin traducir.
  (p.ear || []).forEach(e => steps.push({ type: "ear", item: e }));
  p.reviews.forEach(c => steps.push({ type: "review", card: c }));
  p.new.forEach(c => steps.push({ type: "new", card: c }));
  const sound = tdSound(p);
  const ph = sound ? sound.phoneme : ["θ", "v", "ɪ", "æ", "z"][new Date().getDate() % 5];
  if (DRILLS[labKey(ph)]) DRILLS[labKey(ph)].words.slice(0, 2).forEach(w => steps.push({ type: "sound", phoneme: ph, word: w }));
  steps.push({ type: "speak", mode: p.speak });
  if (p.mistakes.length) steps.push({ type: "mistakes" });
  Object.assign(sess, { steps, i: -1, total: steps.length, done: 0, xp0: d.xp.xp, gained: 0, right: 0, graded: 0, t0: Date.now() });
  $("speakBody").innerHTML = ""; // los ejercicios de hablar se dibujan dentro de la sesión
  $("sessionView").hidden = false; document.body.style.overflow = "hidden";
  $("sessClose").onclick = sessQuit;
  sessNext();
}

function sessProgress() {
  const b = $("sessBar"); b.querySelector("i").style.width = Math.round(sess.done / sess.total * 100) + "%";
  b.setAttribute("aria-valuenow", Math.round(sess.done / sess.total * 100));
  $("sessXp").textContent = sess.gained ? "+" + sess.gained : "";
}
function sessSheet(html, kind) {
  const s = $("sessSheet");
  if (!html) { s.hidden = true; s.innerHTML = ""; return; }
  s.className = "sess-sheet " + (kind || "ok"); s.innerHTML = `<div class="inner">${html}</div>`; s.hidden = false;
  const btn = s.querySelector("[data-next]"); if (btn) { btn.onclick = sessNext; btn.focus(); }
}
function sessAdd(xp) { sess.gained += xp || 0; sessProgress(); }

function sessNext() {
  sessSheet(null);
  if (sess.i >= 0) sess.done = Math.min(sess.total, sess.i + 1);
  sess.i++;
  sessProgress();
  const st = sess.steps[sess.i];
  if (!st) return sess.custom ? sessEndCustom() : sessEnd();
  ({ ear: sessEar, review: sessReview, new: sessNew, sound: sessSoundStep, speak: sessSpeak, mistakes: sessMistakes })[st.type](st);
}

function sessQuit() {
  // Lo hecho ya está guardado (puntos, repasos, errores): salir no pierde nada.
  if (typeof spLeave === "function") { sp.inSession = false; sp.root = null; spLeave(); }
  try { spHush(); } catch (e) {}
  if (stopRecording) stopRecording();
  $("sessionView").hidden = true; document.body.style.overflow = "";
  sp.inSession = false; sp.root = null;
  const back = sess.custom && sess.custom.onEnd; sess.custom = null;
  if (back) back(); else tdOpen();
  refresh();
}

function sessEndCustom() {
  sessActions(""); sp.inSession = false; sp.root = null;
  sess.done = sess.total; sessProgress();
  sessStage(`<div class="sess-end"><div class="sess-check">${SVG.check}</div><h2>¡Listo!</h2>
    <p class="note">${esc(sess.custom.title || "")}${sess.gained ? ` · +${sess.gained} XP` : ""}</p></div>`);
  sessActions(`<button type="button" class="primary sess-big" id="sessDone">Continuar</button>`);
  $("sessDone").onclick = sessQuit;
}

const sessStage = html => { const s = $("sessStage"); s.innerHTML = html; s.scrollTop = 0; return s; };
const sessSay = t => { try { say(t); } catch (e) {} };

// Ficha de repaso: recuerdas la palabra (o, en nivel alto, la sacas de la definición y la frase con hueco).
function sessReview(st) {
  const c = st.card, en = c.english_only, cloze = esc(c.example || "").replace(/\*(.+?)\*/g, '<span class="cloze">_____</span>');
  sessStage(`<span class="sess-kind">${en ? "Solo inglés · ¿qué palabra falta?" : "Repaso · ¿qué significa?"}</span>
    ${en ? `${c.definition ? `<p class="sess-def">${esc(c.definition)}</p>` : ""}<p class="sess-ex">${cloze}</p>` : `<p class="sess-word">${esc(c.word)}</p>`}
    <p class="note">${en ? "Dila en voz alta antes de ver la respuesta." : (spStep() >= 2 ? "Explícalo en voz alta en inglés antes de ver la respuesta." : "Dilo en voz alta (en español o explícalo en inglés) antes de ver la respuesta.")}</p>`);
  if (!en) sessSay(c.word);
  sessActions(`<button type="button" class="primary sess-big" id="sessShow">Ver la respuesta</button>`);
  $("sessShow").onclick = () => {
    sessStage(`<span class="sess-kind">Repaso</span>
      <p class="sess-word">${esc(c.word)} <button type="button" class="round" id="sessSpk" aria-label="Escuchar">${ICON_SPK}</button></p>
      ${en && c.definition ? `<p class="sess-def">${esc(c.definition)}</p>` : meaningHTML(c, "sess-tr", false)}
      <p class="sess-ex">${exHTML(c.example || "")}</p>
      ${en ? (c.hide_translation ? `<p class="es-line">${esPeek(`<span class="sess-tr">${esc(c.translation)}</span>`)}</p>` : `<details class="es-peek"><summary>Ver en español</summary><p class="sess-tr">${esc(c.translation)}</p></details>`) : ""}
      <p class="note">¿Cómo te fue?</p>`);
    $("sessSpk").onclick = () => sessSay(c.word);
    sessSay(c.word);
    const pv = c.previews || { again: 1, hard: 1, good: 3, easy: 7 };
    sessActions(`<div class="sess-grades">${[["again", "Olvidé"], ["hard", "Difícil"], ["good", "Bien"], ["easy", "Fácil"]].map(([g, l]) => `<button type="button" data-g="${g}">${l}<small>${days(pv[g])}</small></button>`).join("")}</div>`);
    document.querySelectorAll(".sess-grades [data-g]").forEach(b => b.onclick = async () => {
      document.querySelectorAll(".sess-grades button").forEach(x => x.disabled = true);
      let r = {}; try { r = await api(`/words/${c.id}/review`, { method: "POST", body: { grade: b.dataset.g } }); } catch (e) { r = { error: e.message }; }
      sess.graded++; if (b.dataset.g !== "again") sess.right++;
      sessAdd(r.xp_gained);
      sessActions("");
      sessSheet(r.error ? `<h3>No se guardó</h3><p>${esc(r.error)}</p><button type="button" class="primary sess-big" data-next>Continuar</button>`
        : b.dataset.g === "again" ? `<h3>La repasarás pronto</h3><p><b>${esc(c.word)}</b>${c.hide_translation ? (c.definition ? " · " + esc(c.definition) : "") : " · " + esc(c.translation)}</p><button type="button" class="primary sess-big" data-next>Continuar</button>`
        : `<h3>${pick(HF_PRAISE)} ${r.xp_gained ? "+" + r.xp_gained + " XP" : ""}</h3><p><b>${esc(c.word)}</b> · vuelve ${days(pv[b.dataset.g])}</p><button type="button" class="primary sess-big" data-next>Continuar</button>`,
        b.dataset.g === "again" || r.error ? "bad" : "ok");
    });
  };
}
function sessActions(html) {
  let a = $("sessActions");
  if (!a) { a = document.createElement("div"); a.id = "sessActions"; a.className = "sess-actions"; $("sessionView").insertBefore(a, $("sessSheet")); }
  a.innerHTML = html; a.hidden = !html;
}

// ---------- Oído: reconocer de oído las palabras aprendidas, por escalones (sonido → significado → frase → rápido) ----------
const EAR_STEPS = { sound: "Sonido", easy: "Significado fácil", definition: "Definición", sentence: "En una frase", fast: "Rápido" };
const EAR_ORDER = ["sound", "easy", "definition", "sentence", "fast"];
function earSay(text, slow) {
  if (useTts()) return playTts(text, "en", !!slow).catch(() => earBrowser(text, slow));
  return earBrowser(text, slow);
}
function earBrowser(text, slow) {
  return new Promise(resolve => {
    if (!("speechSynthesis" in window)) return resolve();
    const u = new SpeechSynthesisUtterance(text); u.lang = "en-US"; if (voice) u.voice = voice; u.rate = slow ? 0.65 : 0.9;
    u.onend = u.onerror = () => resolve(); speechSynthesis.cancel(); speechSynthesis.speak(u);
    setTimeout(resolve, 3000 + text.length * 140);
  });
}
async function earPlay(e) {
  const parts = e.audio && e.audio.length ? e.audio : [{ text: e.word, slow: false }];
  for (let i = 0; i < parts.length; i++) {
    if (i) await new Promise(r => setTimeout(r, 450));
    await earSay(parts[i].text, parts[i].slow);
  }
}
// Las opciones con cada palabra tocable (modo lupa): para entender una definición sin pasar por el español.
const earWords = t => esc(t).replace(/([A-Za-z][A-Za-z'’-]*)/g, '<span class="ear-w" role="button" tabindex="0">$1</span>');
function sessEar(st) {
  const e = st.item, mode = e.mode || "easy", first = sess.steps.findIndex(x => x.type === "ear") === sess.i;
  const step = EAR_ORDER.indexOf(mode) + 1, fastMs = e.fast_ms || 3000, defs = ["definition", "sentence", "fast"].includes(mode);
  let tEnd = 0, answered = false, lens = false;
  const prompt = { sound: "¿Qué palabra oíste?", easy: "¿Qué significa? Toca la respuesta.", definition: "¿Qué significa? Toca la respuesta.",
    sentence: "Oíste una frase y luego la palabra. ¿Qué significa la palabra?", fast: "¿Qué significa? Rápido: tienes 2 segundos." }[mode];
  sessStage(`<span class="sess-kind">Oído · ${esc(EAR_STEPS[mode] || "")}</span>
    <div class="ear-ladder" aria-label="Escalón ${step} de 5">${EAR_ORDER.map((m, k) => `<i class="${k < step ? "on" : ""}"></i>`).join("")}</div>
    ${first ? `<p class="note">Cada palabra sube por escalones: primero reconoces el sonido, luego lo que significa, después dentro de una frase y al final sin pensar. Rápido y sin traducir.</p>` : ""}
    <button type="button" class="ear-play" id="earPlay" aria-label="Oír otra vez">${ICON_SPK}</button>
    <p class="note" id="earHint">Escuchando…</p>
    <div class="ear-opts" id="earOpts" hidden>${e.options.map((o, i) => `<button type="button" class="ear-opt" data-i="${i}">${esc(o)}</button>`).join("")}</div>
    ${defs ? `<div id="earLensBar" hidden><button type="button" class="linkish" id="earLens">🔍 No entiendo una palabra</button></div><p class="ear-look" id="earLook" hidden></p>` : ""}
    <div id="earReveal"></div>`);
  sessActions("");
  const opts = () => $("earOpts").querySelectorAll(".ear-opt");
  const setLens = on => {
    lens = on;
    opts().forEach(b => { b.innerHTML = on ? earWords(e.options[+b.dataset.i]) : esc(e.options[+b.dataset.i]); b.classList.toggle("lens", on); });
    $("earLens").textContent = on ? "✓ Listo, ya entiendo" : "🔍 No entiendo una palabra";
    $("earHint").textContent = on ? "Toca la palabra que no entiendes." : prompt;
  };
  const look = async word => {
    const box = $("earLook"); box.hidden = false; box.textContent = word + "…";
    earSay(word);
    try { const r = await api("/words/lookup?w=" + encodeURIComponent(word)); box.innerHTML = `<b>${esc(r.word)}</b> ${r.emoji ? esc(r.emoji) + " " : ""}= ${esc(r.gloss || r.easy || "")}`; }
    catch (err) { box.textContent = word + ": " + err.message; }
  };
  const play = async () => {
    $("earPlay").classList.add("on"); $("earHint").textContent = "Escuchando…";
    await earPlay(e);
    if (!$("earPlay")) return;
    $("earPlay").classList.remove("on");
    tEnd = Date.now();
    $("earOpts").hidden = false; if ($("earLensBar")) $("earLensBar").hidden = false;
    $("earHint").textContent = lens ? "Toca la palabra que no entiendes." : prompt;
  };
  $("earPlay").onclick = () => answered ? earPlay(e) : play();
  if ($("earLens")) $("earLens").onclick = () => setLens(!lens);
  $("earOpts").onclick = async ev => {
    const w = ev.target.closest(".ear-w");
    if (lens && w) return look(w.textContent);
    const b = ev.target.closest(".ear-opt");
    if (!b || lens || answered || !tEnd) return;
    answered = true;
    const i = +b.dataset.i, ok = i === e.answer, ms = Date.now() - tEnd;
    opts().forEach(x => { x.disabled = true; if (+x.dataset.i === e.answer) x.classList.add("ok"); });
    if (!ok) b.classList.add("bad");
    if ($("earLensBar")) $("earLensBar").hidden = true;
    $("earReveal").innerHTML = mode === "sound" ? "" : `<p class="sess-word" style="font-size:36px">${esc(e.word)}</p>${e.example ? `<p class="sess-ex">${esc(e.example)}</p>` : ""}`;
    $("earHint").textContent = "";
    sess.graded++; if (ok) sess.right++;
    let r = {}; try { r = await api(`/words/${e.id}/ear`, { method: "POST", body: { ok, ms } }); } catch (err) { r = { error: err.message }; }
    sessAdd(r.xp_gained);
    const secs = (ms / 1000).toFixed(1).replace(".", ","), fast = ok && ms <= fastMs;
    const up = fast && r.mode && r.mode !== mode ? `Sube a: ${EAR_STEPS[r.mode] || r.mode}.` : "";
    sessSheet(r.error ? `<h3>No se guardó</h3><p>${esc(r.error)}</p><button type="button" class="primary sess-big" data-next>Continuar</button>`
      : `<h3>${fast ? (r.automatic ? "¡Automática! 🎧" : "¡Al oído!") : ok ? "Bien, pero tardaste" : "Era esta"} ${r.xp_gained ? "+" + r.xp_gained + " XP" : ""}</h3>`
        + `<p>${fast ? "La reconociste en " + secs + " s. " + up : ok ? secs + " s: aún la traduces. Mañana otra vez." : "Mañana la vuelves a oír, un escalón más fácil."}</p>`
        + `<button type="button" class="primary sess-big" data-next>Continuar</button>`, ok ? "ok" : "bad");
  };
  play();
}

// Palabra nueva: la ves, la oyes y la marcas como aprendida.
function sessNew(st) {
  const c = st.card;
  sessStage(`<span class="sess-kind">Palabra nueva</span>
    <p class="sess-word">${esc(c.word)} <button type="button" class="round" id="sessSpk" aria-label="Escuchar">${ICON_SPK}</button></p>
    ${meaningHTML(c, "sess-tr", false)}
    <p class="sess-ex">${exHTML(c.example || "")}</p>${c.hide_translation ? "" : `<p class="note">${esc(c.example_es || "")}</p>`}
    <p class="note">Dila en voz alta dos veces y úsala en una frase tuya.</p>`);
  $("sessSpk").onclick = () => sessSay(c.word);
  sessSay(c.word);
  sessActions(`<button type="button" class="primary sess-big" id="sessGot">La tengo</button>`);
  $("sessGot").onclick = async () => {
    $("sessGot").disabled = true;
    let r = {}; try { r = await api(`/words/${c.id}/learn`, { method: "POST" }); } catch (e) { r = { error: e.message }; }
    sessAdd(r.xp_gained); sessActions("");
    sessSheet(r.error ? `<h3>No se guardó</h3><p>${esc(r.error)}</p><button type="button" class="primary sess-big" data-next>Continuar</button>`
      : `<h3>¡Nueva palabra! ${r.xp_gained ? "+" + r.xp_gained + " XP" : ""}</h3><p>Mañana la repasas.</p><button type="button" class="primary sess-big" data-next>Continuar</button>`, r.error ? "bad" : "ok");
  };
}

// Sonido débil: escuchas la palabra y la dices; se evalúa ese sonido.
function sessSoundStep(st) {
  const t = labTip(labKey(st.phoneme));
  let tries = 0;
  const paint = msg => {
    sessStage(`<span class="sess-kind">Pronunciación · /${esc(st.phoneme)}/ ${esc(t.name)}</span>
      <p class="sess-word">${esc(st.word)} <button type="button" class="round" id="sessSpk" aria-label="Escuchar">${ICON_SPK}</button></p>
      <p class="note">${esc(t.how)}</p>${msg || ""}`);
    $("sessSpk").onclick = () => sessSay(st.word);
  };
  paint(); sessSay(st.word);
  sessActions(`<button type="button" class="sess-mic" id="sessMic" aria-label="Decir la palabra">${SVG.mic}</button><p class="note" style="text-align:center">Toca y dila en voz alta</p>`);
  $("sessMic").onclick = async () => {
    const mic = $("sessMic"); mic.disabled = true; mic.classList.add("rec");
    let pct = 0, silent = false;
    try {
      if (cfg.pronunciation) {
        const wav = await recordWav(3500, null, 0.7);
        if (!wav.heard) silent = true;
        else {
          const fd = new FormData(); fd.append("text", st.word); fd.append("phoneme", st.phoneme); fd.append("audio", wav, "voz.wav");
          const r = await api("/pronunciation/assess", { method: "POST", body: fd });
          pct = r.target_score != null ? r.target_score : r.score;
        }
      } else {
        const alts = await browserListen().catch(() => []);
        if (!alts.length) silent = true; else pct = Math.max(...alts.map(a => compare(st.word, a).pct));
      }
    } catch (e) { paint(`<p class="warnbox">${esc(e.message)}</p>`); }
    mic.disabled = false; mic.classList.remove("rec");
    if (silent) return paint('<p class="warnbox">No te oí. Habla un poco más cerca.</p>');
    tries++;
    const ok = pct >= 80;
    if (ok || tries >= 3) {
      sessActions("");
      sessSheet(`<h3>${ok ? "¡Bien dicho!" : "Sigue practicándolo"}</h3><p>/${esc(st.phoneme)}/ al ${pct}%${ok ? "" : ". En el Taller de pronunciación lo trabajas a fondo."}</p><button type="button" class="primary sess-big" data-next>Continuar</button>`, ok ? "ok" : "bad");
    } else {
      paint(`<p class="warnbox">Sonido al ${pct}%: escúchala otra vez y exagera el movimiento.</p>`);
      sessSay(st.word);
    }
  };
}

// Hablar: el ejercicio del día (narración, foto o shadowing) dentro de la sesión.
function sessSpeak(st) {
  sessActions("");
  const stage = sessStage('<div id="sessSpeakRoot" style="display:grid;gap:16px"></div>');
  sp.root = stage.querySelector("#sessSpeakRoot"); sp.inSession = true;
  const before = sess.gained;
  if (st.mode === "picture" && cfg.pictures) spPicStart();
  else if (st.mode === "shadowing") spShStart(0, st.unit);
  else { sp.stats = sp.stats || null; spNarrStart(0); }
  // Los puntos de hablar los da el servidor al terminar; se ven en el resumen final.
  sess.gained = before;
}

// Errores pendientes: dilos bien.
function sessMistakes() {
  sessActions("");
  const stage = sessStage('<div id="sessSpeakRoot" style="display:grid;gap:16px"></div>');
  sp.root = stage.querySelector("#sessSpeakRoot"); sp.inSession = true;
  spReviewStart();
}

async function sessEnd() {
  sessActions(""); sp.inSession = false; sp.root = null;
  sessStage('<p class="note">Guardando…</p>');
  let r = null; try { r = await api("/session/complete", { method: "POST" }); } catch (e) {}
  const mins = Math.max(1, Math.round((Date.now() - sess.t0) / 60000));
  const xpDay = r ? r.xp.xp : sess.xp0 + sess.gained;
  const earned = Math.max(0, xpDay - sess.xp0);
  const prec = sess.graded ? Math.round(sess.right / sess.graded * 100) + "%" : "—";
  const week = r ? r.xp.week : [];
  const wd = ["D", "L", "M", "X", "J", "V", "S"];
  const tdy = r ? r.today : {};
  const better = [
    tdy.learned ? `${tdy.learned} ${tdy.learned === 1 ? "palabra nueva" : "palabras nuevas"}` : "",
    tdy.mistakes_ok ? `${tdy.mistakes_ok} ${tdy.mistakes_ok === 1 ? "error dicho bien" : "errores dichos bien"}` : "",
    tdy.minutes ? `${String(tdy.minutes).replace(".", ",")} min hablando hoy` : "",
    (tdy.sounds || []).length ? `Sonidos que ya no están en Guiado: ${tdy.sounds.map(s => "/" + s + "/").join(" ")}` : "",
  ].filter(Boolean);
  sess.done = sess.total; sessProgress(); $("sessXp").textContent = "";
  sessStage(`<div class="sess-end">
    <div class="sess-check">${SVG.check}</div>
    <h2>¡Sesión completa!</h2>
    <p class="note">${r && r.xp.xp >= r.xp.goal ? "Cumpliste tu meta de hoy" : `Llevas ${xpDay} de ${r ? r.xp.goal : 100} XP hoy`}</p>
    <div class="sess-tiles">
      <div class="sess-tile"><span>PUNTOS</span><b>+${earned}</b></div>
      <div class="sess-tile g"><span>FICHAS BIEN</span><b>${prec}</b></div>
      <div class="sess-tile o"><span>TIEMPO</span><b>${mins} min</b></div>
    </div>
    ${r ? `<p style="margin:0;font-family:var(--display);font-size:20px;font-weight:800">🔥 ${r.streak} ${r.streak === 1 ? "día" : "días"} seguidos</p>
      <div class="sess-week">${week.map(w => `<div><i class="${w.xp > 0 ? "on" : ""}"></i>${wd[new Date(w.day + "T12:00").getDay()]}</div>`).join("")}</div>` : ""}
    ${better.length ? `<div class="sess-improve"><b>Hoy</b>${better.map(b => `<span>✓ ${esc(b)}</span>`).join("")}</div>` : ""}
    ${r && r.achievements && r.achievements.length ? `<div class="banner ok" style="display:grid;gap:4px;width:100%;text-align:left"><b>🏅 ¡${r.achievements.length === 1 ? "Nuevo logro" : "Nuevos logros"}!</b>${r.achievements.map(a => `<span>${esc(a.title)} · ${esc(a.desc)}</span>`).join("")}</div>` : ""}
  </div>`);
  if (typeof confetti === "function") confetti();
  sessActions(`<button type="button" class="primary sess-big" id="sessDone">Continuar</button><button type="button" id="sessAgain">Otra ronda</button>`);
  $("sessDone").onclick = () => { sessQuit(); };
  $("sessAgain").onclick = () => { sessActions(""); sessStart(); };
}
