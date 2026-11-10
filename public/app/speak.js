/* Word to Word · Hablar
   Conversación por voz con situaciones reales: la IA habla, tú contestas en voz alta y sigue sola.
   Mide cuánto hablas, a qué ritmo y con cuántas pausas; tus errores se guardan para repasarlos diciéndolos bien.
   Usa lo de app.js: api, esc, $, cfg, recordWav, stopRecording, browserListen, SR, playTts, useTts, unlockAudio… */
"use strict";

const sp = {
  view: "home", on: false, paused: false, busy: false, session: null, scenario: null, history: [],
  stats: null, scenarios: null, summary: null, review: null, status: "", mode: "",
  pause: (() => { try { return +localStorage.getItem("wtw_sp_pause") || 2.5; } catch (e) { return 2.5; } })(),
  reviewHf: (() => { try { return localStorage.getItem("wtw_rev_hf") === "1"; } catch (e) { return false; } })(),
};
const SP_STOP = /^(stop|end|finish|terminar|termina|para|pausa|basta)( (please|the conversation|ya|por favor))?$/;

// ---------- abrir / salir ----------
async function spOpen() {
  if (sp.on) return renderSpeak();
  sp.view = sp.view === "talk" ? "home" : sp.view;
  renderSpeak();
  try {
    const [st, sc] = await Promise.all([api("/speaking/stats"), sp.scenarios ? null : api("/speaking/scenarios")]);
    sp.stats = st; if (sc) sp.scenarios = sc.scenarios;
  } catch (e) { sp.status = e.message; }
  renderSpeak();
}
async function spRefreshStats() { try { sp.stats = await api("/speaking/stats"); if (sp.view === "home") renderSpeak(); } catch (e) {} }
// Al cambiar de pestaña a mitad de una conversación, se cierra y se guarda lo hablado.
function spLeave() { if (sp.on) spFinish(true); }

// ---------- voz de la IA ----------
function spSay(text) {
  if (!text) return Promise.resolve();
  sp.mode = "speak"; spStatus("Hablando…");
  if (useTts()) return playTts(text, "en", false).catch(() => spSayBrowser(text));
  return spSayBrowser(text);
}
function spSayBrowser(text) {
  return new Promise(resolve => {
    if (!("speechSynthesis" in window)) return resolve();
    if (speechSynthesis.speaking || speechSynthesis.pending) speechSynthesis.cancel();
    const u = new SpeechSynthesisUtterance(text); u.lang = "en-US"; u.rate = 0.92; if (voice) u.voice = voice;
    let done = false; const fin = () => { if (!done) { done = true; resolve(); } };
    u.onend = fin; u.onerror = fin; setTimeout(fin, 2500 + text.length * 110);
    speechSynthesis.speak(u);
  });
}
function spSayEs(text) {
  if (!text) return Promise.resolve();
  if (useTts()) return playTts(text, "es", false).catch(() => spSayEsBrowser(text));
  return spSayEsBrowser(text);
}
function spSayEsBrowser(text) {
  return new Promise(resolve => {
    if (!("speechSynthesis" in window)) return resolve();
    if (speechSynthesis.speaking || speechSynthesis.pending) speechSynthesis.cancel();
    const u = new SpeechSynthesisUtterance(text); u.lang = "es-ES"; if (typeof esVoice !== "undefined" && esVoice) u.voice = esVoice;
    let done = false; const fin = () => { if (!done) { done = true; resolve(); } };
    u.onend = fin; u.onerror = fin; setTimeout(fin, 2500 + text.length * 110);
    speechSynthesis.speak(u);
  });
}
function spHush() { try { speechSynthesis.cancel(); } catch (e) {} try { ttsAudio.pause(); } catch (e) {} }

// ---------- conversación ----------
async function spStart(id) {
  unlockAudio(); // dentro del toque: el iPhone solo deja hablar y grabar así
  if (hf.on) stopHF(true);
  if (!cfg.ai) { sp.status = "La conversación necesita la IA activada en el servidor (ANTHROPIC_API_KEY)."; return renderSpeak(); }
  if (!cfg.pronunciation && !SR) { sp.status = "Para hablar hace falta el reconocimiento de voz: en el iPhone se activa en el servidor (AZURE_SPEECH_KEY); en el ordenador funciona con Google Chrome."; return renderSpeak(); }
  sp.scenario = (sp.scenarios || []).find(s => s.id === id) || { id, title: id, emoji: "💬" };
  sp.history = []; sp.summary = null; sp.status = ""; sp.busy = true; renderSpeak();
  try { sp.session = (await api("/speaking/sessions", { method: "POST", body: { scenario: id } })).id; }
  catch (e) { sp.busy = false; sp.status = e.message; return renderSpeak(); }
  sp.busy = false; sp.on = true; sp.paused = false; sp.view = "talk";
  try { if ("wakeLock" in navigator) sp.wake = await navigator.wakeLock.request("screen"); } catch (e) {}
  renderSpeak(); spLoop();
}

async function spLoop() {
  if (sp.looping) return; sp.looping = true;
  try {
    while (sp.on && !sp.paused) {
      const last = sp.history[sp.history.length - 1];
      if (!last || last.role === "user") { await spAi(); continue; }
      const r = await spListen();
      if (!sp.on || sp.paused || r.aborted) break;
      if (!r.text) {
        sp.misses = (sp.misses || 0) + 1;
        if (sp.misses >= 2) { sp.paused = true; sp.misses = 0; spStatus("En pausa: no te oí. Pulsa «Seguir» cuando quieras."); renderTalk(); break; }
        spStatus("No te oí. Habla cuando quieras…"); continue;
      }
      sp.misses = 0;
      if (SP_STOP.test(noAccents(r.text))) { await spFinish(); break; }
      sp.history.push({ role: "user", content: r.text, m: r });
      if (sp.stats && r.today != null) sp.stats.today = r.today;
      renderTalk();
    }
  } catch (e) {
    sp.paused = true; spStatus(e.message); renderTalk();
  } finally { sp.looping = false; }
}

async function spAi() {
  sp.mode = ""; spStatus("Pensando…");
  // La primera vez la IA abre la conversación en su papel.
  const msgs = sp.history.slice(-30).map(({ role, content }) => ({ role, content }));
  const r = await api("/conversation", { method: "POST", body: { messages: msgs, scenario: sp.scenario.id, voice: true, session_id: sp.session } });
  if (!sp.on) return;
  const lastUser = [...sp.history].reverse().find(m => m.role === "user");
  if (lastUser) { lastUser.feedback = r.feedback; lastUser.fixes = r.mistakes || []; }
  sp.history.push({ role: "assistant", content: r.reply });
  renderTalk();
  if (!sp.paused) await spSay(r.reply);
}

// Escucha un turno: con Azure graba y el servidor transcribe y mide el ritmo; si no, el navegador.
async function spListen() {
  sp.mode = "listen"; spStatus("Te escucho… habla con calma"); renderControls();
  if (cfg.pronunciation) {
    sp.recording = true; renderControls();
    const wav = await recordWav(45000, null, sp.pause);
    sp.recording = false; renderControls();
    if (sp.abortRec) { sp.abortRec = false; return { aborted: true }; }
    if (!wav.heard) return { text: "" };
    sp.mode = ""; spStatus("Entendiendo lo que dijiste…");
    const fd = new FormData(); fd.append("audio", wav, "voz.wav");
    return await api(`/speaking/sessions/${sp.session}/turns`, { method: "POST", body: fd });
  }
  const t0 = Date.now();
  let alts = [];
  try { alts = await browserListen(); } catch (e) { if (!/No oí/.test(e.message)) throw e; }
  if (!sp.on || sp.paused) return { aborted: true };
  const text = (alts[0] || "").trim();
  if (!text) return { text: "" };
  return await api(`/speaking/sessions/${sp.session}/turns`, { method: "POST", body: { text, ms: Math.min(60000, Math.max(0, Date.now() - t0 - 800)) } });
}

function spPause() {
  sp.paused = true; spHush();
  if (sp.recording && typeof stopRecording === "function" && stopRecording) { sp.abortRec = true; stopRecording(); }
  spStatus("En pausa. Pulsa «Seguir» para continuar."); renderTalk();
}
function spResume() { unlockAudio(); sp.paused = false; sp.misses = 0; renderTalk(); spLoop(); }
// "Ya terminé": corta la grabación sin esperar el silencio.
function spDone() { if (sp.recording && stopRecording) stopRecording(); }

async function spFinish(quiet) {
  if (!sp.session) return;
  const id = sp.session;
  sp.on = false; sp.paused = false; sp.session = null; spHush();
  if (sp.recording && stopRecording) { sp.abortRec = true; stopRecording(); }
  try { sp.wake && sp.wake.release(); } catch (e) {} sp.wake = null;
  try {
    const r = await api(`/speaking/sessions/${id}/finish`, { method: "POST" });
    sp.stats = r.stats;
    if (!quiet) { sp.summary = r; sp.view = "summary"; renderSpeak(); }
  } catch (e) { if (!quiet) { sp.view = "home"; sp.status = e.message; renderSpeak(); } }
}

// ---------- repaso de errores ----------
async function spReviewStart() {
  unlockAudio();
  sp.view = "review"; sp.review = { list: [], i: 0, result: null, shown: false, ok: 0 }; renderSpeak();
  try { sp.review.list = (await api("/speaking/mistakes")).mistakes; } catch (e) { sp.status = e.message; }
  renderSpeak();
  if (sp.reviewHf) spReviewLoop();
}

// Manos libres en el repaso: te lee el error, te escucha decirlo bien y pasa solo al siguiente.
// Comandos (en inglés): "repeat" repite la frase correcta, "skip" salta, "stop" termina.
async function spReviewLoop() {
  const rv = sp.review; if (!rv || rv.looping) return;
  rv.looping = true; rv.misses = 0;
  try {
    while (sp.reviewHf && sp.view === "review" && sp.review === rv && rv.i < rv.list.length) {
      const m = rv.list[rv.i];
      rv.attempts = rv.attempts || 0;
      if (!rv.result) {
        if (!rv.attempts) { await spSayEs("Dijiste:"); await spSay(m.said); if (m.why) await spSayEs(m.why); await spSayEs("Dilo bien."); }
        else await spSayEs("Otra vez.");
        if (!sp.reviewHf || sp.view !== "review") break;
      }
      await spReviewSay();
      if (rv.speaking) await rv.speaking;
      const r = rv.result || {};
      const cmd = typeof labCmd === "function" ? labCmd(r.heard) : null;
      if (cmd === "stop") { sp.reviewHf = false; spSaveRevHf(); renderSpeak(); break; }
      if (cmd === "repeat") { rv.result = null; await spSayEs("Se dice:"); await spSay(m.correct); continue; }
      if (cmd === "skip" || r.passed || (r.passed === false && ++rv.attempts >= 2) || r.error) {
        rv.i++; rv.result = null; rv.shown = false; rv.attempts = 0; rv.misses = 0; renderSpeak();
        await new Promise(res => setTimeout(res, 700));
        continue;
      }
      if (r.silent) {
        if (++rv.misses >= 2) { sp.reviewHf = false; spSaveRevHf(); renderSpeak(); await spSayEs("No te oigo. Lo dejo en pausa."); break; }
        rv.result = null; await spSayEs("No te oí."); continue;
      }
      rv.result = null; // falló: otro intento
    }
    if (sp.reviewHf && sp.view === "review" && rv.i >= rv.list.length && rv.list.length) await spSayEs(`Listo. Dijiste bien ${rv.ok} de ${rv.list.length}.`);
  } finally { rv.looping = false; }
}
function spSaveRevHf() { try { localStorage.setItem("wtw_rev_hf", sp.reviewHf ? "1" : "0"); } catch (e) {} }
async function spReviewSay() {
  const rv = sp.review, m = rv && rv.list[rv.i]; if (!m || sp.busy) return;
  unlockAudio();
  sp.busy = true; rv.result = null; rv.listening = true; renderSpeak();
  try {
    let body;
    if (cfg.pronunciation) {
      const wav = await recordWav(15000, null, 1.4);
      rv.listening = false; renderSpeak();
      if (!wav.heard) { rv.result = { silent: true }; return; }
      body = new FormData(); body.append("audio", wav, "voz.wav");
    } else {
      let alts = []; try { alts = await browserListen(); } catch (e) { if (!/No oí/.test(e.message)) throw e; }
      if (!alts.length) { rv.result = { silent: true }; return; }
      body = { text: alts[0] };
    }
    rv.result = await api(`/speaking/mistakes/${m.id}/review`, { method: "POST", body });
    if (rv.result.passed) rv.ok++;
    if (!rv.result.silent) { rv.shown = true; rv.speaking = spSay(m.correct); }
  } catch (e) { rv.result = { error: e.message }; }
  finally { sp.busy = false; rv.listening = false; renderSpeak(); }
}

// ---------- pantalla ----------
function spStatus(t) { sp.status = t; const el = $("spStatus"); if (el) el.innerHTML = `<span class="hf-dot ${sp.mode}"></span>${esc(t)}`; }
const spMin = n => (Math.round((n || 0) * 10) / 10).toLocaleString("es", { maximumFractionDigits: 1 });

function renderSpeak() {
  const el = $("speakBody"); if (!el) return;
  if (sp.view === "talk") return renderTalk();
  if (sp.view === "summary") el.innerHTML = summaryHTML();
  else if (sp.view === "review") el.innerHTML = reviewHTML();
  else el.innerHTML = homeHTML();
  el.querySelectorAll("[data-sc]").forEach(b => b.onclick = () => spStart(b.dataset.sc));
  const on = (id, fn) => { const b = $(id); if (b) b.onclick = fn; };
  on("spReview", spReviewStart);
  on("spHome", () => { sp.view = "home"; sp.status = ""; spOpen(); });
  on("spSay", spReviewSay);
  on("spShow", () => { sp.review.shown = true; renderSpeak(); spSay(sp.review.list[sp.review.i].correct); });
  on("spListen", () => { unlockAudio(); spSay(sp.review.list[sp.review.i].correct); });
  on("spNext", () => { sp.review.i++; sp.review.result = null; sp.review.shown = false; renderSpeak(); });
  const rh = $("spRevHf"); if (rh) rh.onchange = e => { sp.reviewHf = e.target.checked; spSaveRevHf(); if (sp.reviewHf) { unlockAudio(); spReviewLoop(); } else spHush(); };
  const pz = $("spPauseSel"); if (pz) pz.onchange = e => { sp.pause = +e.target.value; try { localStorage.setItem("wtw_sp_pause", sp.pause); } catch (er) {} };
}

function homeHTML() {
  const st = sp.stats;
  let html = `<div class="kind"><span>Habla en voz alta</span><span>${st ? esc(spMin(st.total_minutes)) + " min en total" : ""}</span></div>`;
  if (sp.status) html += `<p class="warnbox">${esc(sp.status)}</p>`;
  if (st) {
    const pct = Math.min(100, Math.round(st.today / st.goal * 100));
    const done = st.today >= st.goal;
    const max = Math.max(st.goal, ...st.week.map(d => d.minutes));
    const wd = ["D", "L", "M", "X", "J", "V", "S"];
    const w = st.wpm.filter(x => x.wpm), lastW = w.length ? w[w.length - 1].wpm : null, firstW = w.length > 1 ? w[0].wpm : null;
    html += `<div class="sp-goal">
      <div class="sp-goal-top"><b>${esc(spMin(st.today))}</b> de ${st.goal} min hablando hoy ${done ? '<span class="chip sp-ok">¡Meta cumplida!</span>' : ""}</div>
      <div class="sp-bar" role="progressbar" aria-valuenow="${pct}" aria-valuemin="0" aria-valuemax="100"><i style="width:${pct}%"></i></div>
      <p class="note">Solo cuenta el tiempo que <b>tú</b> hablas, sin silencios. ${st.streak ? `🔥 ${st.streak} ${st.streak === 1 ? "día seguido" : "días seguidos"} cumpliendo la meta.` : ""}</p>
    </div>
    <div class="sp-week" aria-label="Minutos hablados los últimos 7 días">${st.week.map(d => {
      const h = max ? Math.round(d.minutes / max * 100) : 0, day = new Date(d.day + "T12:00:00");
      return `<div class="sp-col" title="${esc(spMin(d.minutes))} min"><span class="sp-c"><i style="height:${h}%" class="${d.minutes >= st.goal ? "ok" : ""}"></i><em style="bottom:${Math.round(st.goal / max * 100)}%"></em></span><small>${wd[day.getDay()]}</small></div>`;
    }).join("")}</div>
    <div class="stats">
      <div class="stat"><b>${lastW ?? "—"}</b><span>palabras/min${firstW && lastW ? (lastW > firstW ? " ↑" : lastW < firstW ? " ↓" : "") : ""}</span></div>
      <div class="stat"><b>${st.pauses_per_min ?? "—"}</b><span>pausas largas/min</span></div>
      <div class="stat"><b>${st.mistakes_mastered}</b><span>errores superados</span></div>
    </div>
    <p class="note">Referencia: en una charla normal un nativo dice unas 120–160 palabras por minuto. Que suba tu ritmo y bajen las pausas es fluidez.</p>`;
    if (st.mistakes_due) html += `<button type="button" class="primary" id="spReview">Repasar ${st.mistakes_due} ${st.mistakes_due === 1 ? "error" : "errores"} de tus conversaciones</button>`;
  }
  html += `<h3 class="sp-h">Elige una situación</h3>`;
  html += sp.scenarios ? `<div class="sp-scen">${sp.scenarios.map(s => `<button type="button" data-sc="${esc(s.id)}"${sp.busy ? " disabled" : ""}><span class="sp-e" aria-hidden="true">${esc(s.emoji)}</span><b>${esc(s.title)}</b><small>${esc(s.desc)}</small></button>`).join("")}</div>` : '<p class="note">Cargando…</p>';
  html += `<label class="inl" for="spPauseSel">Cuánto espero cuando haces una pausa
    <select id="spPauseSel" style="width:auto">${[[1.8, "Poco (1,8 s)"], [2.5, "Normal (2,5 s)"], [3.5, "Mucho (3,5 s)"]].map(([v, l]) => `<option value="${v}"${sp.pause === v ? " selected" : ""}>${l}</option>`).join("")}</select></label>
    <p class="note">La IA te habla y te escucha sola, sin botones. Para terminar di <b>«stop»</b> o pulsa Terminar. Al final verás tus errores para repasarlos.</p>`;
  return html;
}

function renderTalk() {
  const el = $("speakBody"); if (!el) return;
  if (!$("spMsgs")) {
    el.innerHTML = `<div class="kind"><span>${esc(sp.scenario.emoji)} ${esc(sp.scenario.title)}</span><span id="spToday"></span></div>
      <p class="sp-status" id="spStatus" aria-live="polite"></p>
      <div class="msgs sp-msgs" id="spMsgs"></div>
      <div class="row" id="spCtl"></div>`;
  }
  $("spMsgs").innerHTML = sp.history.map(m => `<div class="msg ${m.role === "user" ? "me" : "ai"}">${esc(m.content)}</div>${m.role === "user" ? fixHTML(m) : ""}`).join("") || '<p class="note">Preparando la conversación…</p>';
  $("spMsgs").scrollTop = $("spMsgs").scrollHeight;
  if (sp.stats) $("spToday").textContent = spMin(sp.stats.today) + " / " + sp.stats.goal + " min hoy";
  spStatus(sp.status); renderControls();
}
function fixHTML(m) {
  if (!m.feedback && !(m.fixes && m.fixes.length)) return "";
  return `<div class="sp-fb">${m.feedback ? `<p>${esc(m.feedback)}</p>` : ""}${(m.fixes || []).map(f => `<p class="sp-fix"><s>${esc(f.said)}</s> → <b>${esc(f.correct)}</b>${f.why ? ` <span class="note">${esc(f.why)}</span>` : ""}</p>`).join("")}</div>`;
}
function renderControls() {
  const c = $("spCtl"); if (!c) return;
  c.innerHTML = (sp.paused ? '<button type="button" class="primary" id="spGo">Seguir</button>' : `<button type="button" id="spPz">Pausa</button>${sp.recording ? '<button type="button" class="primary" id="spDoneBtn">Ya terminé de hablar</button>' : ""}`)
    + '<button type="button" id="spEnd">Terminar</button>';
  const on = (id, fn) => { const b = $(id); if (b) b.onclick = fn; };
  on("spGo", spResume); on("spPz", spPause); on("spDoneBtn", spDone); on("spEnd", () => spFinish());
}

function summaryHTML() {
  const s = sp.summary, st = sp.stats;
  let html = `<div class="kind"><span>Resumen de la conversación</span><span>${esc((sp.scenario || {}).title || "")}</span></div>
    <div class="stats">
      <div class="stat"><b>${esc(spMin(s.minutes))}</b><span>min hablando</span></div>
      <div class="stat"><b>${s.wpm ?? "—"}</b><span>palabras/min</span></div>
      <div class="stat"><b>${s.pauses_per_min ?? "—"}</b><span>pausas largas/min</span></div>
    </div>`;
  if (st) html += `<p class="note">Hoy llevas <b>${esc(spMin(st.today))}</b> de ${st.goal} min. ${st.today >= st.goal ? "¡Meta del día cumplida! 🎉" : "Una conversación más y la cumples."}</p>`;
  html += s.mistakes.length
    ? `<h3 class="sp-h">Para mejorar (${s.mistakes.length})</h3>${s.mistakes.map(f => `<p class="sp-fix"><s>${esc(f.said)}</s> → <b>${esc(f.correct)}</b>${f.why ? `<br><span class="note">${esc(f.why)}</span>` : ""}</p>`).join("")}
       <p class="note">Repásalos ahora diciéndolos bien en voz alta: es cuando más se fijan. Volverán en tus próximos repasos.</p>
       <button type="button" class="primary" id="spReview">Repasar mis errores ahora</button>`
    : `<p class="banner ok">No se marcaron errores. ¡Muy bien! Prueba una situación más difícil.</p>`;
  return html + `<button type="button" id="spHome">Otra conversación</button>`;
}

function reviewHTML() {
  const rv = sp.review;
  if (!rv.list.length && !sp.status) return `<div class="kind"><span>Repaso de errores</span></div><p class="note">Cargando…</p><button type="button" id="spHome">Volver</button>`;
  if (rv.i >= rv.list.length) return `<div class="kind"><span>Repaso de errores</span></div>
    <p class="banner ok">¡Listo! Dijiste bien ${rv.ok} de ${rv.list.length}. Los que fallaste vuelven mañana.</p><button type="button" class="primary" id="spHome">Volver</button>`;
  const m = rv.list[rv.i], r = rv.result;
  let html = `<div class="kind"><span>Repaso de errores</span><span>${rv.i + 1} / ${rv.list.length}</span></div>
    <label class="switch" for="spRevHf"><input type="checkbox" id="spRevHf" role="switch"${sp.reviewHf ? " checked" : ""}> 🎧 Manos libres</label>
    <p class="note">Dijiste:</p><p class="sp-said"><s>${esc(m.said)}</s></p>
    ${m.why ? `<p class="note">💡 ${esc(m.why)}</p>` : ""}
    <p><b>Dilo bien en voz alta.</b></p>
    ${rv.shown ? `<p class="sp-correct">${esc(m.correct)} <button type="button" class="round" id="spListen" aria-label="Escuchar">${ICON_SPK}</button></p>` : ""}`;
  if (rv.listening) html += `<p class="sp-status"><span class="hf-dot listen"></span>Te escucho…</p>`;
  if (r) {
    if (r.error) html += `<p class="warnbox">${esc(r.error)}</p>`;
    else if (r.silent) html += `<p class="warnbox">No te oí. Habla un poco más cerca del micrófono.</p>`;
    else html += `<p>${(r.tokens || []).map(t => `<span class="tok ${t.ok ? "ok" : "miss"}">${esc(t.w)}</span>`).join("")}</p>
      <p class="${r.passed ? "banner ok" : "warnbox"}">${r.passed ? `¡Bien dicho! Vuelve ${r.mastered ? "— ya lo dominas 🎉" : `en ${r.days} ${r.days === 1 ? "día" : "días"}`}.` : `Entendí: “${esc(r.heard)}”. Escucha la frase y prueba otra vez.`}</p>`;
  }
  const answered = r && !r.silent && !r.error;
  html += `<div class="row">
    ${!answered || !r.passed ? `<button type="button" class="primary" id="spSay"${sp.busy ? " disabled" : ""}>🎙️ ${answered ? "Intentar otra vez" : "Decirlo"}</button>` : ""}
    ${!rv.shown ? '<button type="button" id="spShow">Ver la frase correcta</button>' : ""}
    ${answered ? '<button type="button" id="spNext">Siguiente</button>' : ""}
    <button type="button" id="spHome">Salir</button></div>`;
  return html;
}
