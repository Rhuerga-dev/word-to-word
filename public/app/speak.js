/* Word to Word · Hablar
   Conversación por voz con situaciones reales: la IA habla, tú contestas en voz alta y sigue sola.
   Mide cuánto hablas, a qué ritmo y con cuántas pausas; tus errores se guardan para repasarlos diciéndolos bien.
   Usa lo de app.js: api, esc, $, cfg, recordWav, stopRecording, browserListen, SR, playTts, useTts, unlockAudio… */
"use strict";

const sp = {
  view: "home", on: false, paused: false, busy: false, session: null, scenario: null, history: [],
  stats: null, scenarios: null, summary: null, review: null, status: "", mode: "",
  pause: (() => { try { return +localStorage.getItem("wtw_sp_pause") || 2.5; } catch (e) { return 2.5; } })(),
  quick: (() => { try { return localStorage.getItem("wtw_sp_quick") === "1"; } catch (e) { return false; } })(),
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
function spLeave() {
  if (sp.on) spFinish(true);
  if (sp.view === "narrate" || sp.view === "picture") { if (sp.recording && stopRecording) stopRecording(); if (sp.narrRec) try { sp.narrRec.abort(); } catch (e) {} sp.view = "home"; }
}

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
  mic.keep = true; // el micrófono queda abierto toda la conversación (sin cortes al cambiar de turno)
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
    const t0 = Date.now(); let reaction = null;
    spQuickStart();
    const wav = await recordWav(45000, null, sp.pause, () => { reaction = Date.now() - t0; spQuickStop(true); });
    spQuickStop(false);
    sp.recording = false; renderControls();
    if (sp.abortRec) { sp.abortRec = false; return { aborted: true }; }
    if (!wav.heard) return { text: "" };
    sp.mode = ""; spStatus("Entendiendo lo que dijiste…");
    const fd = new FormData(); fd.append("audio", wav, "voz.wav");
    if (reaction != null) fd.append("reaction_ms", String(Math.min(60000, reaction)));
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

// Respuesta rápida: cuenta de 3 s para empezar a hablar (sin tiempo para traducir).
const SP_QUICK_MS = 3000;
function spQuickStart() {
  const el = $("spQuick"); if (!el) return;
  clearTimeout(sp.quickTimer);
  if (!sp.quick) { el.innerHTML = ""; return; }
  el.innerHTML = '<div class="sp-qbar"><i></i></div><span>Arranca en 3 s, sin traducir</span>';
  requestAnimationFrame(() => { const i = el.querySelector("i"); if (i) { i.style.transition = `width ${SP_QUICK_MS}ms linear`; i.style.width = "0%"; } });
  sp.quickTimer = setTimeout(() => { el.innerHTML = '<span class="sp-qlate">⏱ ¡Arranca! Di lo primero que se te ocurra, aunque sea simple.</span>'; }, SP_QUICK_MS);
}
function spQuickStop(spoke) {
  clearTimeout(sp.quickTimer);
  const el = $("spQuick"); if (!el) return;
  el.innerHTML = spoke && sp.quick ? '<span class="sp-qok">✓ Arrancaste</span>' : "";
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
  sp.on = false; sp.paused = false; sp.session = null; spHush(); releaseMic();
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
  const el = sp.root || $("speakBody"); if (!el) return;
  if (sp.view === "talk") return renderTalk();
  if (sp.view === "narrate") el.innerHTML = narrHTML();
  else if (sp.view === "picture") el.innerHTML = picHTML();
  else if (sp.view === "shadow") el.innerHTML = shHTML();
  else if (sp.view === "scenarios") el.innerHTML = scenariosHTML();
  else if (sp.view === "narrPick") el.innerHTML = narrPickHTML();
  else if (sp.view === "summary") el.innerHTML = summaryHTML();
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
  on("spPic", () => spPicStart());
  on("spGoTalk", () => { sp.view = "scenarios"; sp.status = ""; renderSpeak(); });
  on("spGoNarr", () => { sp.view = "narrPick"; sp.status = ""; renderSpeak(); });
  on("spToProgress", () => showTab("progress"));
  on("spSh", () => spShStart(0));
  on("spShOther", () => spShStart((sp.sh && sp.sh.skip || 0) + 1));
  on("spShListen", () => { unlockAudio(); spShPlay(false); });
  on("spShSlow", () => { unlockAudio(); spShPlay(true); });
  on("spShRec", () => spShTry());
  on("spShHide", () => { sp.sh.hide = !sp.sh.hide; renderSpeak(); });
  on("spShNext", () => { const n = sp.sh; n.i++; n.result = null; n.tries = 0; renderSpeak(); if (n.i < n.sentences.length) spShPlay(false); });
  on("spPicGo", () => spPicGo());
  on("spPicOther", () => spPicStart());
  on("spPicListen", () => { unlockAudio(); spSay(sp.pic && sp.pic.fb && sp.pic.fb.better); });
  on("spPicDone", () => { if (sp.recording && stopRecording) stopRecording(); if (sp.narrRec) try { sp.narrRec.stop(); } catch (e) {} });
  document.querySelectorAll("[data-addw]").forEach(b => b.onclick = () => spAddWord(+b.dataset.addw, b));
  on("spNarrOther", async () => {
    sp.narrSkip = (sp.narrSkip || 0) + 1;
    if (sp.view === "narrPick") { try { sp.stats = await api("/speaking/stats?skip=" + sp.narrSkip); } catch (e) {} renderSpeak(); }
    else spNarrStart(sp.narrSkip);
  });
  on("spNarr", () => spNarrStart(sp.narrSkip || 0));
  on("spNarrAgain", () => spNarrStart(sp.narrSkip || 0));
  on("spNarrListen", () => { unlockAudio(); spSay(sp.narr && sp.narr.fb && sp.narr.fb.better); });
  on("spNarrDone", () => { if (sp.recording && stopRecording) stopRecording(); if (sp.narrRec) try { sp.narrRec.stop(); } catch (e) {} });
  const qo = $("spQuickOn"); if (qo) qo.onchange = e => { sp.quick = e.target.checked; try { localStorage.setItem("wtw_sp_quick", sp.quick ? "1" : "0"); } catch (er) {} };
  const rh = $("spRevHf"); if (rh) rh.onchange = e => { sp.reviewHf = e.target.checked; spSaveRevHf(); if (sp.reviewHf) { unlockAudio(); spReviewLoop(); } else spHush(); };
  // Dentro de la sesión guiada de "Hoy": al terminar se sigue con el siguiente paso, sin desvíos.
  if (sp.inSession) {
    const h = $("spHome"); if (h) { h.textContent = "Continuar"; h.className = "primary sess-big"; h.onclick = () => { sp.inSession = false; sp.root = null; sp.view = "home"; if (typeof sessNext === "function") sessNext(); }; }
    ["spReview", "spPicOther", "spShOther", "spNarrOther"].forEach(id => { const b = $(id); if (b && !(id === "spPicOther" && sp.pic && sp.pic.phase === "error")) b.remove(); });
  }
  const pz = $("spPauseSel"); if (pz) pz.onchange = e => { sp.pause = +e.target.value; try { localStorage.setItem("wtw_sp_pause", sp.pause); } catch (er) {} };
}

function homeHTML() {
  const st = sp.stats;
  let html = `<div class="kind"><span>Habla en voz alta</span><span><button type="button" class="linkish" id="spToProgress">📊 Ver progreso</button></span></div>`;
  if (sp.status) html += `<p class="warnbox">${esc(sp.status)}</p>`;
  if (st) {
    const pct = Math.min(100, Math.round(st.today / st.goal * 100)), done = st.today >= st.goal;
    html += `<div class="sp-goal">
      <div class="sp-goal-top"><b>${esc(spMin(st.today))}</b> de ${st.goal} min hoy ${done ? '<span class="chip sp-ok">¡Meta cumplida!</span>' : ""}${st.streak ? ` <span class="note">🔥 ${st.streak} ${st.streak === 1 ? "día" : "días"}</span>` : ""}</div>
      <div class="sp-bar" role="progressbar" aria-valuenow="${pct}" aria-valuemin="0" aria-valuemax="100"><i style="width:${pct}%"></i></div></div>`;
    if (st.mistakes_due) html += `<button type="button" class="primary" id="spReview">🔁 Repasar ${st.mistakes_due} ${st.mistakes_due === 1 ? "error" : "errores"}</button>`;
  }
  const narr = st && st.narrated_today;
  html += `<div class="sp-tiles">
    <button type="button" class="sp-tile" id="spGoTalk"><span>💬</span><b>Conversación</b><small>Elige una situación real y habla con la IA</small></button>
    <button type="button" class="sp-tile" id="spGoNarr"><span>🗣️</span><b>Narración del día ${narr ? "✓" : ""}</b><small>Un minuto hablando sin parar</small></button>
    <button type="button" class="sp-tile" id="spPic"${cfg.pictures ? "" : " disabled"}><span>🖼️</span><b>Describe la imagen</b><small>${cfg.pictures ? "Dices lo que ves en una foto" : "Falta configurar las fotos"}</small></button>
    <button type="button" class="sp-tile" id="spSh"><span>🔁</span><b>Shadowing</b><small>Repite frases como un nativo</small></button>
  </div>`;
  html += `<details class="sp-settings"><summary>Ajustes de voz</summary>
    <label class="switch" for="spQuickOn"><input type="checkbox" id="spQuickOn" role="switch"${sp.quick ? " checked" : ""}> ⚡ Respuesta rápida</label>
    <p class="note">Tienes 3 segundos para empezar a contestar: así no da tiempo a traducir.</p>
    <label class="inl" for="spPauseSel">Cuánto espero cuando haces una pausa
      <select id="spPauseSel" style="width:auto">${[[1.8, "Poco (1,8 s)"], [2.5, "Normal (2,5 s)"], [3.5, "Mucho (3,5 s)"]].map(([v, l]) => `<option value="${v}"${sp.pause === v ? " selected" : ""}>${l}</option>`).join("")}</select></label>
  </details>`;
  return html;
}

// Segundo paso de "Conversación": elegir la situación.
function scenariosHTML() {
  return `<div class="kind"><span>💬 Elige una situación</span><span><button type="button" class="linkish" id="spHome">← Volver</button></span></div>
    ${sp.status ? `<p class="warnbox">${esc(sp.status)}</p>` : ""}
    <p class="note">La IA te habla y te escucha sola, sin botones. Para terminar di <b>«stop»</b> o pulsa Terminar.</p>
    ${sp.scenarios ? `<div class="sp-scen">${sp.scenarios.map(x => `<button type="button" data-sc="${esc(x.id)}"${sp.busy ? " disabled" : ""}><span class="sp-e" aria-hidden="true">${esc(x.emoji)}</span><b>${esc(x.title)}</b><small>${esc(x.desc)}</small></button>`).join("")}</div>` : '<p class="note">Cargando…</p>'}`;
}

// Antes de la narración: el tema del día, con opción de cambiarlo.
function narrPickHTML() {
  const st = sp.stats, tp = st && st.topic;
  return `<div class="kind"><span>🗣️ Narración del día</span><span><button type="button" class="linkish" id="spHome">← Volver</button></span></div>
    ${sp.status ? `<p class="warnbox">${esc(sp.status)}</p>` : ""}
    ${tp ? `<p class="sp-topic">${esc(tp.en)}</p><p class="note">${esc(tp.es)}</p>` : ""}
    <p class="note">Hablas un minuto sin parar, sin preparar nada. Luego ves una versión más natural de lo que dijiste y tus errores.</p>
    <div class="row"><button type="button" class="primary" id="spNarr"${sp.busy ? " disabled" : ""}>🎙️ Empezar</button><button type="button" id="spNarrOther"${sp.busy ? " disabled" : ""}>Otro tema</button></div>`;
}

function renderTalk() {
  const el = sp.root || $("speakBody"); if (!el) return;
  if (!$("spMsgs")) {
    el.innerHTML = `<div class="kind"><span>${esc(sp.scenario.emoji)} ${esc(sp.scenario.title)}</span><span id="spToday"></span></div>
      <p class="sp-status" id="spStatus" aria-live="polite"></p>
      <div class="sp-quick" id="spQuick" aria-live="polite"></div>
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
      ${s.reaction != null ? `<div class="stat"><b>${String(s.reaction).replace(".", ",")} s</b><span>para arrancar</span></div>` : ""}
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

// ---------- narración diaria (1 minuto) ----------
// Con el navegador (sin Azure): reconocimiento continuo hasta que pulses "Terminé" o pase el tiempo.
function spListenLong(ms) {
  return new Promise((resolve, reject) => {
    if (!SR) return reject(new Error("Este navegador no reconoce voz. Usa Google Chrome."));
    const r = new SR(); sp.narrRec = r; r.lang = "en-US"; r.continuous = true; r.interimResults = false;
    const parts = []; const t = setTimeout(() => { try { r.stop(); } catch (e) {} }, ms);
    r.onresult = e => { for (let i = e.resultIndex; i < e.results.length; i++) if (e.results[i].isFinal) parts.push(e.results[i][0].transcript); };
    r.onerror = e => { if (e.error !== "no-speech" && e.error !== "aborted") { clearTimeout(t); reject(new Error("Error de voz: " + e.error)); } };
    r.onend = () => { clearTimeout(t); sp.narrRec = null; resolve(parts.join(" ").trim()); };
    r.start();
  });
}

async function spNarrStart(skip) {
  unlockAudio();
  if (hf.on) stopHF(true);
  if (!cfg.ai) { sp.status = "La narración necesita la IA activada en el servidor (ANTHROPIC_API_KEY)."; return renderSpeak(); }
  if (!cfg.pronunciation && !SR) { sp.status = "Para hablar hace falta el reconocimiento de voz (AZURE_SPEECH_KEY en el servidor, o Google Chrome)."; return renderSpeak(); }
  sp.busy = true; sp.status = ""; renderSpeak();
  let r;
  try { r = await api("/speaking/sessions", { method: "POST", body: { scenario: "narrate", skip } }); }
  catch (e) { sp.busy = false; sp.status = e.message; return renderSpeak(); }
  sp.busy = false;
  sp.narr = { id: r.id, topic: r.topic, seconds: r.seconds || 60, phase: "intro", left: r.seconds || 60, text: "", fb: null, summary: null };
  sp.scenario = { id: "narrate", title: "Narración del día", emoji: "🗣️" };
  sp.view = "narrate"; renderSpeak();
  try {
    await spSay(r.topic.en);
    if (sp.view !== "narrate") return;
    await spSayEs("Habla un minuto. Empieza ya.");
    await spNarrRecord();
  } catch (e) { sp.narr.phase = "error"; sp.narr.error = e.message; renderSpeak(); }
}

async function spNarrRecord() {
  const n = sp.narr; n.phase = "rec"; n.left = n.seconds; renderSpeak();
  const t0 = Date.now(); let reaction = null;
  clearInterval(n.tick);
  n.tick = setInterval(() => { n.left = Math.max(0, n.seconds - Math.round((Date.now() - t0) / 1000)); const el = $("spNarrLeft"); if (el) el.textContent = n.left; }, 500);
  let turn;
  try {
    if (cfg.pronunciation) {
      sp.recording = true;
      // Azure acepta hasta 60 s por audio; se corta solo tras 4 s de silencio.
      const wav = await recordWav(Math.min(58000, n.seconds * 1000), null, 4.0, () => { reaction = Date.now() - t0; });
      sp.recording = false;
      if (sp.view !== "narrate") return;
      if (!wav.heard) throw new Error("No te oí. Acércate al micrófono y prueba otra vez.");
      n.phase = "wait"; renderSpeak();
      const fd = new FormData(); fd.append("audio", wav, "voz.wav");
      if (reaction != null) fd.append("reaction_ms", String(Math.min(60000, reaction)));
      turn = await api(`/speaking/sessions/${n.id}/turns`, { method: "POST", body: fd });
    } else {
      const text = await spListenLong(n.seconds * 1000);
      if (sp.view !== "narrate") return;
      if (!text) throw new Error("No te oí. Acércate al micrófono y prueba otra vez.");
      n.phase = "wait"; renderSpeak();
      turn = await api(`/speaking/sessions/${n.id}/turns`, { method: "POST", body: { text, ms: Math.min(60000, Date.now() - t0) } });
    }
  } finally { clearInterval(n.tick); sp.recording = false; }
  if (!turn.text) throw new Error("No se entendió lo que dijiste. Prueba otra vez, un poco más alto.");
  n.text = turn.text;
  n.fb = await api(`/speaking/sessions/${n.id}/narration`, { method: "POST", body: { text: turn.text } });
  n.summary = await api(`/speaking/sessions/${n.id}/finish`, { method: "POST" });
  sp.stats = n.summary.stats;
  n.phase = "done"; renderSpeak();
  if (n.fb.comment) await spSay(n.fb.comment);
}

function narrHTML() {
  const n = sp.narr; if (!n) return "";
  let html = `<div class="kind"><span>🗣️ Narración del día</span><span>${n.phase === "rec" ? `<b id="spNarrLeft">${n.left}</b> s` : ""}</span></div>
    <p class="sp-topic">${esc(n.topic.en)}</p><p class="note">${esc(n.topic.es)}</p>`;
  if (n.phase === "intro") html += '<p class="sp-status"><span class="hf-dot speak"></span>Escucha el tema…</p>';
  if (n.phase === "rec") html += `<p class="sp-status"><span class="hf-dot listen"></span>Te escucho: habla sin parar, aunque te equivoques.</p>
    <p class="note">Si te quedas en blanco, describe lo que ves o di <i>"what I mean is…"</i> y sigue.</p>
    <div class="row"><button type="button" class="primary" id="spNarrDone">Terminé</button></div>`;
  if (n.phase === "wait") html += '<p class="sp-status"><span class="hf-dot"></span>Revisando lo que dijiste…</p>';
  if (n.phase === "error") html += `<p class="warnbox">${esc(n.error)}</p><div class="row"><button type="button" class="primary" id="spNarrAgain">Intentar otra vez</button><button type="button" id="spHome">Volver</button></div>`;
  if (n.phase === "done") {
    const s = n.summary || {}, fb = n.fb || {};
    html += `<div class="stats">
        <div class="stat"><b>${esc(spMin(s.minutes))}</b><span>min hablando</span></div>
        <div class="stat"><b>${s.wpm ?? "—"}</b><span>palabras/min</span></div>
        <div class="stat"><b>${s.reaction != null ? String(s.reaction).replace(".", ",") + " s" : "—"}</b><span>para arrancar</span></div>
      </div>
      ${fb.comment ? `<p class="msg ai">${esc(fb.comment)}</p>` : ""}
      ${fb.feedback ? `<p class="note">${esc(fb.feedback)}</p>` : ""}
      <details class="sp-said-all"><summary>Lo que dijiste</summary><p>${esc(n.text)}</p></details>
      ${fb.better ? `<h3 class="sp-h">Así sonaría más natural</h3><p class="sp-better">${esc(fb.better)} <button type="button" class="round" id="spNarrListen" aria-label="Escuchar">${ICON_SPK}</button></p>
        <p class="note">Léela en voz alta una vez: copiar el ritmo de una versión natural de <b>tus propias ideas</b> es de lo que más ayuda.</p>` : ""}
      ${(fb.mistakes || []).length ? `<h3 class="sp-h">Para mejorar (${fb.mistakes.length})</h3>${fb.mistakes.map(f => `<p class="sp-fix"><s>${esc(f.said)}</s> → <b>${esc(f.correct)}</b>${f.why ? `<br><span class="note">${esc(f.why)}</span>` : ""}</p>`).join("")}
        <button type="button" class="primary" id="spReview">Repasar mis errores ahora</button>` : '<p class="banner ok">Sin errores importantes. ¡Muy bien!</p>'}
      <div class="row"><button type="button" id="spHome">Volver</button></div>`;
  }
  return html;
}

// ---------- describe la imagen ----------
async function spPicStart() {
  unlockAudio();
  if (hf.on) stopHF(true);
  if (!cfg.ai) { sp.status = "Necesita la IA activada en el servidor (ANTHROPIC_API_KEY)."; return renderSpeak(); }
  if (!cfg.pronunciation && !SR) { sp.status = "Para hablar hace falta el reconocimiento de voz (AZURE_SPEECH_KEY en el servidor, o Google Chrome)."; return renderSpeak(); }
  sp.view = "picture"; sp.pic = { phase: "loading", photo: null }; sp.scenario = { id: "picture", title: "Describe la imagen", emoji: "🖼️" };
  renderSpeak();
  try { sp.pic.photo = await api("/speaking/picture"); sp.pic.phase = "look"; }
  catch (e) { sp.pic.phase = "error"; sp.pic.error = e.message; }
  renderSpeak();
}

async function spPicGo() {
  unlockAudio();
  const n = sp.pic; if (!n || !n.photo) return;
  try {
    const r = await api("/speaking/sessions", { method: "POST", body: { scenario: "picture" } });
    n.id = r.id; n.seconds = r.seconds || 45;
    await spSayEs("Describe la foto. Empieza ya.");
    if (sp.view !== "picture") return;
    n.phase = "rec"; n.left = n.seconds; renderSpeak();
    const t0 = Date.now(); let reaction = null, turn;
    clearInterval(n.tick);
    n.tick = setInterval(() => { n.left = Math.max(0, n.seconds - Math.round((Date.now() - t0) / 1000)); const el = $("spPicLeft"); if (el) el.textContent = n.left; }, 500);
    try {
      if (cfg.pronunciation) {
        sp.recording = true;
        const wav = await recordWav(n.seconds * 1000, null, 4.0, () => { reaction = Date.now() - t0; });
        sp.recording = false;
        if (sp.view !== "picture") return;
        if (!wav.heard) throw new Error("No te oí. Acércate al micrófono y prueba otra vez.");
        n.phase = "wait"; renderSpeak();
        const fd = new FormData(); fd.append("audio", wav, "voz.wav");
        if (reaction != null) fd.append("reaction_ms", String(Math.min(60000, reaction)));
        turn = await api(`/speaking/sessions/${n.id}/turns`, { method: "POST", body: fd });
      } else {
        const text = await spListenLong(n.seconds * 1000);
        if (sp.view !== "picture") return;
        if (!text) throw new Error("No te oí. Acércate al micrófono y prueba otra vez.");
        n.phase = "wait"; renderSpeak();
        turn = await api(`/speaking/sessions/${n.id}/turns`, { method: "POST", body: { text, ms: Math.min(60000, Date.now() - t0) } });
      }
    } finally { clearInterval(n.tick); sp.recording = false; }
    if (!turn.text) throw new Error("No se entendió lo que dijiste. Prueba otra vez, un poco más alto.");
    n.text = turn.text;
    n.fb = await api(`/speaking/sessions/${n.id}/picture`, { method: "POST", body: { text: turn.text, image_url: n.photo.url } });
    n.summary = await api(`/speaking/sessions/${n.id}/finish`, { method: "POST" });
    sp.stats = n.summary.stats;
    n.phase = "done"; renderSpeak();
    if (n.fb.comment) await spSay(n.fb.comment);
  } catch (e) { n.phase = "error"; n.error = e.message; renderSpeak(); }
}

async function spAddWord(i, btn) {
  const w = sp.pic && sp.pic.fb && sp.pic.fb.missed[i]; if (!w) return;
  btn.disabled = true;
  try { const r = await api("/words/personal", { method: "POST", body: w }); btn.textContent = r.added ? "✓ En tus fichas" : "✓ Ya la tenías"; w.added = true; }
  catch (e) { btn.disabled = false; btn.textContent = "Reintentar"; sp.pic.error = e.message; }
}

function picHTML() {
  const n = sp.pic; if (!n) return "";
  const ph = n.photo;
  let html = `<div class="kind"><span>🖼️ Describe la imagen</span><span>${n.phase === "rec" ? `<b id="spPicLeft">${n.left}</b> s` : ""}</span></div>`;
  if (ph) html += `<figure class="sp-photo"><img src="${esc(ph.url)}" alt="${esc(ph.alt || "Foto para describir")}" referrerpolicy="no-referrer">
      <figcaption>Foto de <a href="${esc(ph.author_url)}" target="_blank" rel="noopener">${esc(ph.author)}</a> en <a href="${esc(ph.unsplash_url)}" target="_blank" rel="noopener">Unsplash</a></figcaption></figure>`;
  if (n.phase === "loading") html += '<p class="note">Buscando una foto…</p>';
  if (n.phase === "look") html += `<p class="note">Mírala unos segundos. Di qué hay, qué hace la gente, dónde están, colores, cómo crees que se sienten…</p>
    <div class="row"><button type="button" class="primary" id="spPicGo">🎙️ Empezar a describir</button><button type="button" id="spPicOther">Otra foto</button><button type="button" id="spHome">Volver</button></div>`;
  if (n.phase === "rec") html += `<p class="sp-status"><span class="hf-dot listen"></span>Te escucho: describe todo lo que ves.</p>
    <p class="note">¿No sabes una palabra? Descríbela con otras (<i>"the thing you use to…"</i>) y sigue.</p>
    <div class="row"><button type="button" class="primary" id="spPicDone">Terminé</button></div>`;
  if (n.phase === "wait") html += '<p class="sp-status"><span class="hf-dot"></span>La IA está mirando la foto y lo que dijiste…</p>';
  if (n.phase === "error") html += `<p class="warnbox">${esc(n.error)}</p><div class="row">${ph ? '<button type="button" class="primary" id="spPicGo">Intentar otra vez</button>' : ""}<button type="button" id="spPicOther">Otra foto</button><button type="button" id="spHome">Volver</button></div>`;
  if (n.phase === "done") {
    const s = n.summary || {}, fb = n.fb || {};
    html += `<div class="stats">
        <div class="stat"><b>${esc(spMin(s.minutes))}</b><span>min hablando</span></div>
        <div class="stat"><b>${s.wpm ?? "—"}</b><span>palabras/min</span></div>
        <div class="stat"><b>${s.reaction != null ? String(s.reaction).replace(".", ",") + " s" : "—"}</b><span>para arrancar</span></div>
      </div>
      ${fb.comment ? `<p class="msg ai">${esc(fb.comment)}</p>` : ""}
      ${fb.feedback ? `<p class="note">${esc(fb.feedback)}</p>` : ""}
      <details class="sp-said-all"><summary>Lo que dijiste</summary><p>${esc(n.text)}</p></details>
      ${(fb.missed || []).length ? `<h3 class="sp-h">Palabras que te faltaron</h3><div class="sp-missed">${fb.missed.map((w, i) => `<div class="sp-mw"><div><b>${esc(w.word)}</b> <span class="note">${esc(w.translation)}</span><br><span class="ex">${exHTML(w.example)}</span></div>
          <button type="button" data-addw="${i}"${w.added ? " disabled" : ""}>${w.added ? "✓ En tus fichas" : "+ A mis fichas"}</button></div>`).join("")}</div>` : ""}
      ${fb.better ? `<h3 class="sp-h">Una descripción más natural</h3><p class="sp-better">${esc(fb.better)} <button type="button" class="round" id="spPicListen" aria-label="Escuchar">${ICON_SPK}</button></p>` : ""}
      ${(fb.mistakes || []).length ? `<h3 class="sp-h">Para mejorar (${fb.mistakes.length})</h3>${fb.mistakes.map(f => `<p class="sp-fix"><s>${esc(f.said)}</s> → <b>${esc(f.correct)}</b>${f.why ? `<br><span class="note">${esc(f.why)}</span>` : ""}</p>`).join("")}
        <button type="button" class="primary" id="spReview">Repasar mis errores ahora</button>` : ""}
      <div class="row"><button type="button" class="primary" id="spPicOther">Otra foto</button><button type="button" id="spHome">Volver</button></div>`;
  }
  return html;
}

// ---------- shadowing ----------
async function spShStart(skip) {
  unlockAudio();
  if (hf.on) stopHF(true);
  if (!cfg.ai) { sp.status = "Necesita la IA activada en el servidor (ANTHROPIC_API_KEY)."; return renderSpeak(); }
  if (!cfg.pronunciation && !SR) { sp.status = "Para evaluar tu voz hace falta Azure Speech en el servidor o Google Chrome."; return renderSpeak(); }
  sp.view = "shadow"; sp.sh = { phase: "loading", skip, i: 0, tries: 0, result: null, hide: false, scores: [] };
  renderSpeak();
  try { Object.assign(sp.sh, await api("/speaking/shadowing" + (skip ? "?skip=" + skip : "")), { phase: "go" }); }
  catch (e) { sp.sh.phase = "error"; sp.sh.error = e.message; }
  renderSpeak();
  if (sp.sh.phase === "go") spShPlay(false);
}
function spShPlay(slow) {
  const n = sp.sh, t = n && n.sentences && n.sentences[n.i]; if (!t) return Promise.resolve();
  if (useTts()) return playTts(t, "en", slow).catch(() => spSayBrowser(t));
  return spSayBrowser(t);
}
// Repites la frase: con Azure se evalúa sonido por sonido y la fluidez; sin Azure, las palabras.
async function spShTry() {
  const n = sp.sh, t = n.sentences[n.i]; if (!t || n.busy) return;
  unlockAudio();
  n.busy = true; n.result = null; n.listening = true; renderSpeak();
  try {
    if (cfg.pronunciation) {
      const wav = await recordWav(3000 + t.split(" ").length * 600, null, 1.0);
      n.listening = false; renderSpeak();
      if (!wav.heard) { n.result = { silent: true }; return; }
      const fd = new FormData(); fd.append("text", t); fd.append("audio", wav, "voz.wav");
      const r = await api("/pronunciation/assess", { method: "POST", body: fd });
      const a = r.assessment || {};
      if (a.status !== "Success") { n.result = { silent: true }; return; }
      n.result = { score: r.score, fluency: a.scores && a.scores.fluency, accuracy: a.scores && a.scores.accuracy,
        words: (a.words || []).filter(w => w.error !== "Insertion").map(w => ({ w: w.word, ok: w.error === "None" && w.accuracy >= 60 })) };
    } else {
      let alts = []; try { alts = await browserListen(); } catch (e) { if (!/No oí/.test(e.message)) throw e; }
      n.listening = false;
      if (!alts.length) { n.result = { silent: true }; return; }
      let best = null; alts.forEach(x => { const c = compare(t, x); if (!best || c.pct > best.pct) best = c; });
      n.result = { score: best.pct, words: best.toks.map(z => ({ w: z.x, ok: z.ok })) };
    }
    n.tries++;
    n.result.passed = n.result.score >= 75;
    if (n.result.passed || n.tries >= 3) n.scores[n.i] = Math.max(n.scores[n.i] || 0, n.result.score);
  } catch (e) { n.result = { error: e.message }; }
  finally { n.busy = false; n.listening = false; renderSpeak(); }
}

function shHTML() {
  const n = sp.sh; if (!n) return "";
  let html = `<div class="kind"><span>🔁 Shadowing${n.title ? " · " + esc(n.title) : ""}</span><span>${n.sentences ? Math.min(n.i + 1, n.sentences.length) + " / " + n.sentences.length : ""}</span></div>`;
  if (n.phase === "loading") return html + '<p class="note">Preparando el texto…</p>';
  if (n.phase === "error") return html + `<p class="warnbox">${esc(n.error)}</p><div class="row"><button type="button" class="primary" id="spShOther">Intentar con otro</button><button type="button" id="spHome">Volver</button></div>`;
  if (n.i >= n.sentences.length) {
    const sc = n.scores.filter(x => x != null), avg = sc.length ? Math.round(sc.reduce((a, b) => a + b, 0) / sc.length) : 0;
    return html + `<p class="banner ok">¡Terminaste! Promedio: <b>${avg}%</b>. Repetir el mismo texto mañana, ya sin mirarlo, es lo que más fija el ritmo.</p>
      <div class="row"><button type="button" class="primary" id="spShOther">Otro texto</button><button type="button" id="spHome">Volver</button></div>`;
  }
  const t = n.sentences[n.i], r = n.result;
  html += `<p class="note">Escucha y repite <b>justo después</b>, copiando el ritmo, las pausas y cómo se unen las palabras, no solo las palabras.</p>
    <p class="sp-shline${n.hide ? " hidden-text" : ""}">${n.hide ? "🙈 Texto oculto: repítelo de oído" : esc(t)}</p>
    <div class="row"><button type="button" id="spShListen">🔊 Escuchar</button><button type="button" id="spShSlow">🐢 Lento</button><button type="button" class="linkish" id="spShHide">${n.hide ? "Mostrar texto" : "Ocultar texto"}</button></div>`;
  if (n.listening) html += '<p class="sp-status"><span class="hf-dot listen"></span>Te escucho…</p>';
  if (r) {
    if (r.error) html += `<p class="warnbox">${esc(r.error)}</p>`;
    else if (r.silent) html += '<p class="warnbox">No te oí. Habla un poco más cerca del micrófono.</p>';
    else html += `<p>${r.words.map(w => `<span class="tok ${w.ok ? "ok" : "miss"}">${esc(w.w)}</span>`).join("")}</p>
      <div class="stats"><div class="stat"><b>${r.score}%</b><span>pronunciación</span></div>${r.fluency != null ? `<div class="stat"><b>${r.fluency}%</b><span>fluidez</span></div>` : ""}${r.accuracy != null ? `<div class="stat"><b>${r.accuracy}%</b><span>precisión</span></div>` : ""}</div>
      <p class="${r.passed ? "banner ok" : "note"}">${r.passed ? "¡Muy bien! Sonó natural." : n.tries >= 3 ? "Seguimos: vuelve a ella mañana." : "Escúchala otra vez (prueba 🐢 Lento) y repítela."}</p>`;
  }
  const done = r && !r.silent && !r.error && (r.passed || n.tries >= 3);
  html += `<div class="row">${!done ? `<button type="button" class="primary" id="spShRec"${n.busy ? " disabled" : ""}>🎙️ ${n.tries ? "Otra vez" : "Repetir"}</button>` : ""}
    ${done || n.tries ? `<button type="button" class="${done ? "primary" : ""}" id="spShNext">Siguiente</button>` : ""}<button type="button" id="spHome">Salir</button></div>`;
  return html;
}
