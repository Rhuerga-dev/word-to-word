// Lógica de Word to Word (antes estaba dentro de index.html; fuera, la CSP no necesita 'unsafe-inline').
// ===== Cliente de la API =====
const API = "/api";
let token = null; try { token = localStorage.getItem("wtw_token"); } catch (e) {}
async function api(path, opts = {}) {
  const headers = Object.assign({ Accept: "application/json" }, opts.headers || {});
  if (token) headers.Authorization = "Bearer " + token;
  let body = opts.body;
  if (body && !(body instanceof FormData)) { headers["Content-Type"] = "application/json"; body = JSON.stringify(body); }
  const res = await fetch(API + path, { method: opts.method || "GET", headers, body });
  if (res.status === 401) { setToken(null); showAuth(); throw new Error("Tu sesión expiró. Entra otra vez."); }
  if (res.status === 204) return null;
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const msg = data.errors ? Object.values(data.errors).flat()[0] : (data.message || ("Error " + res.status));
    throw new Error(msg);
  }
  return data;
}
function setToken(t) { token = t; try { t ? localStorage.setItem("wtw_token", t) : localStorage.removeItem("wtw_token"); } catch (e) {} }

// ===== Utilidades =====
const $ = id => document.getElementById(id);
function esc(s) { return String(s ?? "").replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c])); }
function exHTML(ex) { return esc(ex).replace(/\*(.+?)\*/g, "<em>$1</em>"); }
function plain(ex) { return String(ex || "").replace(/\*/g, ""); }
function days(n) { return n === 1 ? "mañana" : "en " + n + " días"; }
const ICON_SPK = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M11 5 6 9H3v6h3l5 4z" fill="currentColor"/><path d="M15.5 8.5a5 5 0 0 1 0 7M18.5 5.5a9 9 0 0 1 0 13"/></svg>';
const ICON_FLAME = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 2c1 4 5 5.5 5 11a5 5 0 0 1-10 0c0-2.5 1.2-4 2.5-5.2.2 1.8 1 3 2.2 3.4C11 8.6 11 5 12 2z" fill="currentColor"/></svg>';
const ICON_MIC = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="9" y="3" width="6" height="11" rx="3" fill="currentColor"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/></svg>';
$("dictBtn").innerHTML = ICON_MIC;

// ===== Voz (TTS del navegador) =====
let voice = null;
function pickVoice() { const vs = speechSynthesis.getVoices(); voice = vs.find(v => /en-US/i.test(v.lang) && /Samantha|Google US|Aria|Jenny/i.test(v.name)) || vs.find(v => /en-US/i.test(v.lang)) || null; }
if ("speechSynthesis" in window) { pickVoice(); speechSynthesis.onvoiceschanged = pickVoice; }
// ===== Voz natural (Azure) =====
// Un solo <audio> para todo: el iPhone lo desbloquea con el primer toque y luego deja usarlo.
const ttsAudio = new Audio(); ttsAudio.preload = "auto";
const ttsCache = new Map();
const SILENT_MP3 = "data:audio/mpeg;base64,SUQzBAAAAAAAI1RTU0UAAAAPAAADTGF2ZjU2LjM2LjEwMAAAAAAAAAAAAAAA//OEAAAAAAAAAAAAAAAAAAAAAAAASW5mbwAAAA8AAAAEAAABIADAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV6urq6urq6urq6urq6urq6urq6urq6urq6v////////////////////////////////8AAAAATGF2YzU2LjQxAAAAAAAAAAAAAAAAJAAAAAAAAAAAASDs90hvAAAAAAAAAAAAAAAAAAAA//MUZAAAAAGkAAAAAAAAA0gAAAAATEFN//MUZAMAAAGkAAAAAAAAA0gAAAAARTMu//MUZAYAAAGkAAAAAAAAA0gAAAAAOTku//MUZAkAAAGkAAAAAAAAA0gAAAAANVVV";
function unlockTts() { try { ttsAudio.src = SILENT_MP3; const p = ttsAudio.play(); if (p) p.catch(() => {}); } catch (e) {} }
async function ttsUrl(text, lang, slow) {
  const key = lang + "|" + (slow ? 1 : 0) + "|" + text;
  if (ttsCache.has(key)) return ttsCache.get(key);
  // Si el servidor tarda más de 10 s, se usa la voz del teléfono en vez de dejar al alumno esperando.
  const ctl = new AbortController(), timer = setTimeout(() => ctl.abort(), 10000);
  let res;
  try { res = await fetch(API + "/tts?" + new URLSearchParams({ text, lang, slow: slow ? 1 : 0 }), { headers: { Accept: "audio/mpeg", Authorization: "Bearer " + token }, signal: ctl.signal }); }
  finally { clearTimeout(timer); }
  if (!res.ok) throw new Error("tts " + res.status);
  const url = URL.createObjectURL(await res.blob());
  ttsCache.set(key, url);
  return url;
}
// Reproduce con voz natural; devuelve una promesa que termina cuando acaba de hablar.
async function playTts(text, lang, slow) {
  const url = await ttsUrl(text, lang, slow);
  return new Promise((resolve, reject) => {
    let done = false; const fin = ok => { if (done) return; done = true; ttsAudio.onended = ttsAudio.onerror = null; ok ? resolve() : reject(new Error("audio")); };
    ttsAudio.onended = () => fin(true); ttsAudio.onerror = () => fin(false);
    ttsAudio.src = url;
    const p = ttsAudio.play(); if (p) p.catch(() => fin(false));
    setTimeout(() => fin(true), 4000 + text.length * 150);
  });
}
const useTts = () => cfg.tts && token;
// El primer toque en cualquier parte desbloquea el audio en el iPhone.
["touchend", "click"].forEach(ev => document.addEventListener(ev, function once() { unlockTts(); document.removeEventListener("touchend", once, true); document.removeEventListener("click", once, true); }, true));

function say(text, slow) {
  if (useTts()) { try { speechSynthesis.cancel(); } catch (e) {} playTts(text, "en", slow).catch(() => sayBrowser(text, slow)); return; }
  sayBrowser(text, slow);
}
function sayBrowser(text, slow) { if (!("speechSynthesis" in window)) return; speechSynthesis.cancel(); const u = new SpeechSynthesisUtterance(text); u.lang = "en-US"; if (voice) u.voice = voice; u.rate = slow ? 0.6 : 0.9; speechSynthesis.speak(u); }

// ===== Grabación WAV 16 kHz (para Azure) =====
let stopRecording = null;
let hfAudioCtx = null;
// ===== Micrófono =====
// Con audífonos Bluetooth (AirPods), abrir el micrófono pasa el audio a "modo llamada": la voz suena peor y el
// cambio tarda un momento (se pierde el principio de lo que dices). Por eso:
// - se puede elegir el micrófono del iPhone (los AirPods siguen en alta calidad para escuchar),
// - en una conversación el micrófono queda abierto todo el rato (sin cambiar de modo en cada turno).
const mic = { stream: null, keep: false, pref: (() => { try { return localStorage.getItem("wtw_mic") || ""; } catch (e) { return ""; } })() };
async function getMic() {
  if (mic.stream && mic.stream.getAudioTracks().some(t => t.readyState === "live")) return mic.stream;
  const audio = { channelCount: 1, echoCancellation: true, noiseSuppression: true, autoGainControl: true };
  if (mic.pref) audio.deviceId = { exact: mic.pref };
  let stream;
  try { stream = await navigator.mediaDevices.getUserMedia({ audio }); }
  catch (e) { if (!mic.pref) throw e; delete audio.deviceId; stream = await navigator.mediaDevices.getUserMedia({ audio }); } // el elegido ya no está
  mic.stream = stream;
  return stream;
}
function releaseMic() { mic.keep = false; if (mic.stream) { mic.stream.getTracks().forEach(t => t.stop()); mic.stream = null; } }
async function listMics() {
  try { return (await navigator.mediaDevices.enumerateDevices()).filter(d => d.kind === "audioinput" && d.deviceId); } catch (e) { return []; }
}

// onVoice: se llama una vez cuando empieza a oírse tu voz (para medir cuánto tardas en arrancar).
async function recordWav(maxMs = 6000, onStart, silenceSec = 1.0, onVoice) {
  const stream = await getMic();
  // En manos libres se reusa el contexto de audio que se desbloqueó con el toque (iPhone).
  const shared = hfAudioCtx && hfAudioCtx.state !== "closed";
  const ctx = shared ? hfAudioCtx : new (window.AudioContext || window.webkitAudioContext)();
  if (ctx.state === "suspended") { try { await ctx.resume(); } catch (e) {} } // iPhone
  const src = ctx.createMediaStreamSource(stream);
  const proc = ctx.createScriptProcessor(4096, 1, 1);
  const chunks = []; let silentFor = 0, heard = false, level = 0.02; const calib = [];
  src.connect(proc); proc.connect(ctx.destination);
  onStart && onStart();
  return new Promise(resolve => {
    let done = false;
    const stop = () => {
      if (done) return; done = true; stopRecording = null;
      proc.disconnect(); src.disconnect(); if (!mic.keep) releaseMic();
      const rate = ctx.sampleRate; if (!shared) ctx.close();
      const wav = encodeWav(downsample(flatten(chunks), rate, 16000), 16000);
      wav.heard = heard; // false = no se oyó a nadie (solo silencio o ruido)
      resolve(wav);
    };
    const timer = setTimeout(stop, maxMs);
    stopRecording = () => { clearTimeout(timer); stop(); };
    proc.onaudioprocess = e => {
      const d = new Float32Array(e.inputBuffer.getChannelData(0)); chunks.push(d);
      let rms = 0; for (let i = 0; i < d.length; i++) rms += d[i] * d[i]; rms = Math.sqrt(rms / d.length);
      // Umbral según el ruido de fondo de los primeros ~0,25 s: los micrófonos Bluetooth graban más bajo.
      if (calib.length < 3 && !heard) { calib.push(rms); if (calib.length === 3) { const floor = Math.min(...calib); level = Math.min(0.02, Math.max(0.006, floor * 3)); } }
      if (rms > level) { if (!heard && onVoice) { try { onVoice(); } catch (er) {} } heard = true; silentFor = 0; } else if (heard) { silentFor += d.length / ctx.sampleRate; if (silentFor > silenceSec) { clearTimeout(timer); stop(); } }
    };
  });
}
function flatten(cs) { const n = cs.reduce((a, c) => a + c.length, 0), out = new Float32Array(n); let o = 0; cs.forEach(c => { out.set(c, o); o += c.length; }); return out; }
function downsample(buf, from, to) { if (from === to) return buf; const r = from / to, n = Math.floor(buf.length / r), out = new Float32Array(n); for (let i = 0; i < n; i++) { const s = Math.floor(i * r), e = Math.floor((i + 1) * r); let sum = 0; for (let j = s; j < e; j++) sum += buf[j]; out[i] = sum / (e - s); } return out; }
function encodeWav(samples, rate) {
  const b = new ArrayBuffer(44 + samples.length * 2), v = new DataView(b);
  const w = (o, s) => { for (let i = 0; i < s.length; i++) v.setUint8(o + i, s.charCodeAt(i)); };
  w(0, "RIFF"); v.setUint32(4, 36 + samples.length * 2, true); w(8, "WAVE"); w(12, "fmt "); v.setUint32(16, 16, true); v.setUint16(20, 1, true); v.setUint16(22, 1, true);
  v.setUint32(24, rate, true); v.setUint32(28, rate * 2, true); v.setUint16(32, 2, true); v.setUint16(34, 16, true); w(36, "data"); v.setUint32(40, samples.length * 2, true);
  for (let i = 0; i < samples.length; i++) { const s = Math.max(-1, Math.min(1, samples[i])); v.setInt16(44 + i * 2, s < 0 ? s * 0x8000 : s * 0x7fff, true); }
  return new Blob([b], { type: "audio/wav" });
}

// ===== Reconocimiento del navegador (modo sin Azure y dictado) =====
const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
function norm(s) { return s.toLowerCase().replace(/[’']/g, "").replace(/[^a-z0-9\s]/g, " ").split(/\s+/).filter(Boolean); }
function compare(target, heard) { const t = norm(target), pool = norm(heard); const toks = t.map(x => { const i = pool.indexOf(x); if (i > -1) { pool.splice(i, 1); return { x, ok: true }; } return { x, ok: false }; }); return { toks, pct: t.length ? Math.round(toks.filter(z => z.ok).length / t.length * 100) : 0 }; }
function browserListen() {
  return new Promise((resolve, reject) => {
    if (!SR) return reject(new Error("Este navegador no reconoce voz. Usa Google Chrome."));
    const r = new SR(); r.lang = "en-US"; r.maxAlternatives = 4; r.interimResults = false;
    r.onresult = e => resolve([...e.results[0]].map(a => a.transcript));
    r.onerror = e => reject(new Error((e.error === "service-not-allowed" || /iPhone|iPad/.test(navigator.userAgent)) && e.error !== "no-speech" ? "En el iPhone el reconocimiento del navegador no funciona. Hay que activar la evaluación en el servidor (AZURE_SPEECH_KEY)." : e.error === "not-allowed" ? "Permite el micrófono en el navegador." : e.error === "no-speech" ? "No oí nada. Habla más cerca." : "Error de voz: " + e.error));
    r.start();
  });
}

// ===== Estado =====
let cfg = { ai: false, pronunciation: false, time_travel: false };
let cards = [], revealed = false, showHint = false, stats = null;

// ===== Auth =====
// Modos: login | register | forgot | reset
let authMode = "login", resetToken = null;
function setAuthMode(mode) {
  authMode = mode;
  const titles = { login: "Entrar", register: "Crear cuenta", forgot: "Recuperar contraseña", reset: "Contraseña nueva" };
  const submits = { login: "Entrar", register: "Crear cuenta", forgot: "Enviarme el enlace", reset: "Guardar contraseña" };
  $("authTitle").textContent = titles[mode];
  $("authSubmit").textContent = submits[mode];
  $("nameWrap").hidden = mode !== "register";
  $("passWrap").hidden = mode === "forgot";
  $("aPass").required = mode !== "forgot";
  $("aPass").autocomplete = mode === "login" ? "current-password" : "new-password";
  $("pass2Wrap").hidden = mode !== "reset";
  $("aPass2").required = mode === "reset";
  $("aEmail").readOnly = mode === "reset";
  $("authSwitch").textContent = mode === "login" ? "Crear cuenta" : "Volver a entrar";
  $("forgotLink").hidden = mode !== "login";
  $("authHelp").hidden = !(mode === "forgot" || mode === "reset");
  $("authHelp").textContent = mode === "forgot" ? "Escribe tu correo y te enviamos un enlace para crear una contraseña nueva." : mode === "reset" ? "Elige una contraseña nueva de al menos 8 caracteres." : "";
  $("authErr").textContent = ""; $("authOk").textContent = "";
}
function showAuth() { $("authView").hidden = false; $("appView").hidden = true; $("logoutBtn").hidden = true; $("daypill").hidden = true; $("lvlChip").hidden = true; $("streakChip").hidden = true; }
$("authSwitch").onclick = () => setAuthMode(authMode === "login" ? "register" : "login");
$("forgotLink").onclick = () => setAuthMode("forgot");
$("authForm").onsubmit = async e => {
  e.preventDefault(); $("authErr").textContent = ""; $("authOk").textContent = "";
  const btn = $("authSubmit"); btn.disabled = true;
  try {
    const email = $("aEmail").value.trim(), password = $("aPass").value;
    if (authMode === "forgot") {
      const r = await api("/auth/forgot-password", { method: "POST", body: { email } });
      $("authOk").textContent = r.message;
    } else if (authMode === "reset") {
      if (password !== $("aPass2").value) throw new Error("Las contraseñas no coinciden.");
      const r = await api("/auth/reset-password", { method: "POST", body: { token: resetToken, email, password, password_confirmation: $("aPass2").value } });
      resetToken = null; $("aPass").value = ""; $("aPass2").value = "";
      setAuthMode("login"); $("authOk").textContent = r.message;
    } else {
      const body = { email, password };
      if (authMode === "register") { body.name = $("aName").value || "Estudiante"; body.timezone = userTimezone(); }
      const r = await api(authMode === "register" ? "/auth/register" : "/auth/login", { method: "POST", body });
      setToken(r.token); start();
    }
  } catch (err) { $("authErr").textContent = err.message; }
  btn.disabled = false;
};
async function startDemo() {
  const b = $("demoBtn"); if (b) { b.disabled = true; b.textContent = "Preparando tu demo…"; }
  try { const r = await api("/auth/demo", { method: "POST" }); setToken(r.token); await start(); }
  catch (e) { $("authErr").textContent = e.message; }
  if (b) { b.disabled = false; b.textContent = "Probar la demo, sin registrarte"; }
}
$("demoBtn").onclick = startDemo;
$("logoutBtn").onclick = async () => { try { await api("/auth/logout", { method: "POST" }); } catch (e) {} setToken(null); profile = null; applyUiLang(); showAuth(); setAuthMode("login"); };
function userTimezone() { try { return Intl.DateTimeFormat().resolvedOptions().timeZone || "America/New_York"; } catch (e) { return "America/New_York"; } }

// ===== Carga =====
async function start() {
  $("authView").hidden = true; $("appView").hidden = false; $("logoutBtn").hidden = false; $("daypill").hidden = false;
  try { cfg = await api("/config"); } catch (e) {}
  $("svc").textContent = "IA: " + (cfg.ai ? "activa" : "sin configurar") + " · Pronunciación: " + (cfg.pronunciation ? "Azure" : "navegador");
  $("nextDay").hidden = true; // solo en la demo (abajo, cuando se sabe quién es)
  $("chatMode").textContent = cfg.ai ? "" : "Necesita ANTHROPIC_API_KEY";
  try { profile = await api("/me"); } catch (e) { return; }
  applyUiLang();
  $("nextDay").hidden = !(cfg.time_travel && profile.demo);
  renderBanners(); renderSettings(); loadFamilies();
  await loadLevels();
  if (!profile.cefr_level) { placementIntro(); return; }
  await refresh();
  showTab("today");
}
async function refresh() {
  try {
    const [t, s] = await Promise.all([api("/today"), api("/stats")]);
    cards = t.cards; stats = s; revealed = false; showHint = false;
    $("dailyNew").value = t.daily_new;
    render(); renderSide();
  } catch (e) { $("main").innerHTML = '<p class="warnbox">' + esc(e.message) + "</p>"; }
}

// ===== Ficha =====
function speakingBlock() {
  return `<div class="section"><h3>Practica speaking ${cfg.pronunciation ? "· evaluado por Azure" : ""}</h3>
    <div class="row"><button type="button" class="icon primary" data-say="sentence">${ICON_MIC} Decir la frase</button>
    <span class="note">Toca la frase para oírla despacio.</span></div>
    <div class="heard" id="heard"><span class="note">Escucha la frase, luego pulsa el micrófono (o <kbd>M</kbd>) y repítela.</span></div>
    <div id="drill"></div></div>`;
}
function aidBlock(c, nudge) {
  return `<div class="section"><h3>Tu escena AID</h3>
    ${nudge ? '<p class="warnbox">Fallaste esta palabra ' + c.fails + ' veces. Crea una escena absurda para fijarla.</p>' : ""}
    <textarea id="aid" placeholder="Ej.: suena a “…”. Imagina una acción absurda, exagerada y con detalles…">${esc(c.aid || "")}</textarea>
    <div class="row">${cfg.ai ? '<button type="button" id="suggBtn">Sugerir escenas con IA</button>' : ""}<span class="sync" id="aidState"></span></div>
    <div class="sugg" id="sugg"></div></div>`;
}

// ===== Toques amigables =====
const pick = a => a[Math.floor(Math.random() * a.length)];
const lsGet = k => { try { return localStorage.getItem(k); } catch (e) { return null; } };
let dayTotal = 0;
// ===== Escalera de español: cada vez menos español para pensar en inglés =====
// 1 = todo con español · 2 = primero inglés, español al tocar · 3 = interfaz en inglés y español con límite · 4 = solo inglés.
function spStep() { return (profile && profile.spanish && profile.spanish.step) || 1; }
/** Español a pedido: un botón "Ver en español" que, al tocarlo, cuenta un uso (y respeta el límite del escalón). */
function esPeek(html, kind = "translation") {
  if (!html) return "";
  if (spStep() <= 1) return html;
  if (spStep() >= 4) return "";
  return `<span class="es-ask" data-kind="${kind}"><button type="button" class="linkish es-btn">Ver en español</button><span class="es-hidden" hidden>${html}</span></span>`;
}
/** Botón para traducir al español un texto del coach (cuenta un uso). Nada en los escalones 1 y 4. */
function esTranslate(text) {
  if (!text || spStep() <= 1 || spStep() >= 4) return "";
  return `<span class="es-ask" data-translate="${esc(text)}"><button type="button" class="linkish es-btn">Traducir</button><span class="es-hidden note" hidden></span></span>`;
}
/** Lo que significa una palabra según el escalón: traducción (1) o definición en inglés con el español a pedido (2–4). */
function meaningHTML(c, cls = "tr", withExample = true) {
  if (!c.hide_translation) return `<p class="${cls}">${esc(c.translation)}</p>` + (withExample && c.example_es ? `<p class="ex-es">${esc(c.example_es)}</p>` : "");
  const peek = esPeek(`<span class="${cls}">${esc(c.translation)}</span>${withExample && c.example_es ? `<br><span class="ex-es">${esc(c.example_es)}</span>` : ""}`);
  return `${c.definition ? `<p class="def">${esc(c.definition)}</p>` : ""}${peek ? `<p class="es-line">${peek}</p>` : ""}`;
}
document.addEventListener("click", async e => {
  const b = e.target.closest(".es-btn"); if (!b) return;
  const box = b.closest(".es-ask"), out = box.querySelector(".es-hidden");
  b.disabled = true;
  try {
    if (box.dataset.translate) {
      const r = await api("/spanish/translate", { method: "POST", body: { text: box.dataset.translate } });
      out.textContent = r.text;
    } else {
      await api("/spanish/use", { method: "POST", body: { kind: box.dataset.kind || "translation" } });
    }
    b.remove(); out.hidden = false;
    if (profile && profile.spanish) profile.spanish.today++;
  } catch (err) { b.replaceWith(Object.assign(document.createElement("span"), { className: "note", textContent: err.message })); }
});

function firstName() { const n = (profile && profile.name || "").trim().split(/\s+/)[0]; return n && !["Estudiante", "Invitado"].includes(n) ? n : ""; }
function greeting() { const h = new Date().getHours(); return h < 5 ? "Buenas noches" : h < 12 ? "Buenos días" : h < 19 ? "Buenas tardes" : "Buenas noches"; }
function stageLabel(c) {
  if (c.mode === "new") return "✨ Palabra nueva";
  if (c.level <= 0) return "🌱 La estás aprendiendo";
  if (c.level <= 2) return "🌿 Ya la conoces un poco";
  if (c.level === 3) return "🌳 Casi la dominas";
  return "⭐ Repaso rápido";
}
function commonness(rank) { return rank <= 1000 ? "Muy común" : rank <= 3000 ? "Común" : "Útil"; }
function toast(msg) {
  let t = $("toast"); if (!t) { t = document.createElement("div"); t.id = "toast"; t.className = "toast"; t.setAttribute("role", "status"); document.body.appendChild(t); }
  t.textContent = msg; t.classList.add("show"); clearTimeout(toast.timer); toast.timer = setTimeout(() => t.classList.remove("show"), 1600);
}
const PRAISE = { learn: ["¡Guardada! ✨", "¡Una más para tu colección!", "¡Genial, a la lista! 📚"],
  good: ["¡Bien! 💪", "¡Eso es!", "¡Lo sabías! 👏", "¡Excelente!"], easy: ["¡Facilísima! 🚀", "¡La dominas! ⭐"],
  hard: ["Bien, la repasamos pronto 👍", "Poco a poco 💡"], again: ["Tranquilo, la verás otra vez pronto 🙂", "Normal, así se aprende 💪"] };
const HF_PRAISE = ["¡Bien!", "¡Muy bien!", "¡Eso es!", "¡Perfecto!", "¡Excelente!", "¡Así se dice!"];
function renderHello() {
  const box = $("hello"); if (!box || !profile) return;
  if (!lsGet("wtw_onboarded") && !profile.demo_seen_tip) {
    box.innerHTML = `<div class="onboard"><h2>👋 ¡Bienvenido${firstName() ? ", " + esc(firstName()) : ""}! Así funciona:</h2>
      <ol><li><b>Cada día</b> repasas las palabras de ayer y aprendes ${+($("dailyNew") || {}).value || 10} nuevas. Mañana repasas las de hoy y aprendes otras nuevas. Así, día a día.</li>
      <li><b>Escucha</b> la palabra tocándola y repítela en voz alta.</li>
      <li><b>Desliza la ficha</b>: a la derecha si la sabías, a la izquierda si no. La app decide cuándo volver a mostrártela.</li>
      <li>Activa <b>Manos libres</b> para practicar sin mirar la pantalla, con consejos de pronunciación.</li></ol>
      <button type="button" class="primary" id="onboardOk">¡Empecemos!</button></div>`;
    $("onboardOk").onclick = () => { try { localStorage.setItem("wtw_onboarded", "1"); } catch (e) {} profile.demo_seen_tip = true; renderHello(); };
    return;
  }
  const left = cards.length; dayTotal = Math.max(dayTotal, left); const done = dayTotal - left;
  const streak = stats ? stats.streak : 0, pct = dayTotal ? Math.round(done / dayTotal * 100) : 100;
  let line;
  if (!left) line = "Terminaste por hoy 🎉 ¡Gran trabajo!";
  else if (!done) line = streak ? `Llevas ${streak} ${streak === 1 ? "día" : "días"} seguidos 🔥 Unos minutos hoy y la mantienes.` : "Empecemos con calma: una palabra a la vez. 🌱";
  else if (pct < 50) line = pick(["¡Buen comienzo! Sigue así.", "Vas muy bien 💪", "¡Una a una se aprende!"]);
  else if (pct < 90) line = pick(["¡Ya pasaste la mitad! 🙌", "¡Te falta poco!", "Vas volando 🚀"]);
  else line = "¡Última recta! Ya casi terminas. 🏁";
  const nNew = cards.filter(x => x.mode === "new").length, nRev = left - nNew;
  const plan = left ? `<p><b>Plan de hoy:</b> ${nRev ? `repasar ${nRev} ${nRev === 1 ? "palabra" : "palabras"} que ya viste` : ""}${nRev && nNew ? " y " : ""}${nNew ? `aprender ${nNew} ${nNew === 1 ? "nueva" : "nuevas"}` : ""}.</p>` : "";
  box.innerHTML = `<div class="hello"><h2>${greeting()}${firstName() ? ", " + esc(firstName()) : ""} 👋</h2><p>${line}</p>${plan}
    ${dayTotal ? `<div class="goal"><div class="bar"><i style="width:${pct}%"></i></div><small><span>Meta de hoy</span><span>${done} de ${dayTotal}</span></small></div>` : ""}</div>`;
}
function confetti() {
  try {
    const c = document.createElement("canvas"); c.id = "confetti"; document.body.appendChild(c);
    const ctx = c.getContext("2d"), W = c.width = innerWidth, H = c.height = innerHeight;
    const colors = ["#7aa2ff", "#4cc68a", "#ffe45c", "#ef7a7a", "#b38cff"];
    const ps = Array.from({ length: 140 }, () => ({ x: Math.random() * W, y: -20 - Math.random() * H * .5, r: 4 + Math.random() * 5, c: pick(colors), vy: 2 + Math.random() * 3, vx: -1.5 + Math.random() * 3, a: Math.random() * 6 }));
    let t = 0; (function frame() { ctx.clearRect(0, 0, W, H); ps.forEach(p => { p.x += p.vx; p.y += p.vy; p.a += .1; ctx.fillStyle = p.c; ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.a); ctx.fillRect(-p.r / 2, -p.r / 2, p.r, p.r * .6); ctx.restore(); });
      if (++t < 180) requestAnimationFrame(frame); else c.remove(); })();
  } catch (e) {}
}


// ----- Tarjeta de enfoque: lo que estás aprendiendo, grande y fijo en el centro -----
function focusCard(c) {
  const isNew = c.mode === "new", left = cards.length; dayTotal = Math.max(dayTotal, left);
  const showMeaning = isNew || revealed, sentence = hf.mode === "sentences" || hfPhase(c) === "sentence";
  return `<div class="focus-card" id="theCard">
    <div class="focus-top"><span>${stageLabel(c)}${c.family ? " · " + c.family.emoji + " " + esc(c.family.label) : ""}</span><span>${dayTotal - left + 1} de ${dayTotal}</span></div>
    <div class="focus-step" id="focusStep">${$("hfState") ? $("hfState").innerHTML : ""}</div>
    <h2 class="fw">${esc(c.word)}</h2>
    ${showMeaning ? meaningHTML(c, "ftr", false) : '<p class="ftr hidden">¿Qué significa?</p>'}
    ${showMeaning && c.aid ? `<div class="faid"><b>Tu escena</b>${esc(c.aid)}</div>` : ""}
    ${showMeaning && sentence ? `<p class="fex">${exHTML(c.example)}</p>${c.hide_translation ? "" : `<p class="fex-es">${esc(c.example_es)}</p>`}` : ""}
    <div class="heard" id="heard"></div>
    <div id="drill"></div>
  </div>`;
}

function render() {
  const nNew = cards.filter(c => c.mode === "new").length, nRev = cards.length - nNew;
  $("queue").innerHTML = `<span>Te quedan:</span><span class="chip rev">${nRev} ${nRev === 1 ? "repaso" : "repasos"}</span><span class="chip new">${nNew} ${nNew === 1 ? "nueva" : "nuevas"}</span>`;
  renderHello();
  if (stats) $("daypill").textContent = new Date(stats.today + "T12:00").toLocaleDateString("es", { weekday: "long", day: "numeric", month: "short" });
  const main = $("main"), c = cards[0];
  if (hf.on && c) { main.innerHTML = focusCard(c); return; }
  if (!c) {
    const tm = stats ? stats.forecast[0].count : 0, streak = stats ? stats.streak : 0;
    const name = firstName();
    main.innerHTML = `<div class="card"><div class="card-top"></div><div class="card-body done">
      <div class="big">🎉</div>
      <h2>¡Lo lograste${name ? ", " + esc(name) : ""}!</h2>
      <p class="note">Terminaste tus palabras de hoy.${streak ? ` Llevas <b>${streak} ${streak === 1 ? "día" : "días"} seguidos</b> 🔥` : ""}</p>
      <div class="today">${dayTotal ? `<span>✅ ${dayTotal} fichas hoy</span>` : ""}${stats ? `<span>📚 ${stats.learned} aprendidas</span><span>⭐ ${stats.mastered} dominadas</span>` : ""}</div>
      <p class="note"><b>Mañana:</b> repasarás ${tm} ${tm === 1 ? "palabra" : "palabras"} (entre ellas las que aprendiste hoy) y aprenderás ${+($("dailyNew") || {}).value || 10} nuevas. ¡Te espero!</p>
      <div class="row"><button type="button" class="primary" id="goChat">🎙️ Practicar hablando</button>
      ${cfg.time_travel && profile && profile.demo ? '<button type="button" id="goNext">Simular mañana</button>' : ""}</div></div></div>`;
    if ($("goNext")) $("goNext").onclick = nextDay;
    if ($("goChat")) $("goChat").onclick = () => showTab("speak");
    const today = stats ? stats.today : "";
    if (dayTotal && lsGet("wtw_celebrated") !== today) { try { localStorage.setItem("wtw_celebrated", today); } catch (e) {} confetti(); }
    return;
  }
  const isNew = c.mode === "new";
  // Ficha avanzada sin español: recuerdas la palabra desde la definición en inglés y una frase con hueco.
  const enOnly = !isNew && c.english_only && !hf.on;
  const cloze = enOnly ? esc(c.example).replace(/\*(.+?)\*/g, '<span class="cloze">_____</span>') : "";
  const front = enOnly && !revealed ? `<div class="kind"><span class="stage">🇺🇸 Solo inglés</span><span>${famChip(c)}${commonness(c.rank)}</span></div>` : `<div class="kind"><span class="stage">${stageLabel(c)}</span><span>${famChip(c)}${commonness(c.rank)}${c.best_pron_score != null ? " · 🎙️ " + c.best_pron_score + "%" : ""}</span></div>
    <div class="word-row"><h2 class="word tappable" id="spk" role="button" tabindex="0" title="Toca para escuchar">${esc(c.word)}</h2></div>`;
  let body;
  if (isNew) {
    body = `${meaningHTML(c, "tr", false)}<div><p class="ex tappable" data-slow="1" role="button" tabindex="0">${exHTML(c.example)}</p>${c.hide_translation ? "" : `<p class="ex-es">${esc(c.example_es)}</p>`}</div>
      ${speakingBlock()}${aidBlock(c, false)}
      <p class="gesture">Desliza la ficha a la derecha → cuando la tengas<span class="keys"> · o pulsa <kbd>Enter</kbd></span></p>`;
  } else if (enOnly && !revealed) {
    body = `${c.definition ? `<p class="def">${esc(c.definition)}</p>` : ""}<p class="ex">${cloze}</p>
      <p class="hint">¿Qué palabra falta? Dila en inglés, sin pasar por el español.</p>
      <p class="gesture">Toca la ficha para ver la respuesta<span class="keys"> · o pulsa <kbd>Espacio</kbd></span></p>`;
  } else if (!revealed) {
    body = `<p class="hint">¿Qué significa? Dilo en voz alta antes de ver la respuesta.</p>
      ${c.aid ? (showHint ? `<p class="warnbox">Pista AID: ${esc(c.aid)}</p>` : '<p class="note tappable" id="hintBtn" role="button" tabindex="0">¿Necesitas una pista? Toca aquí (o <kbd>H</kbd>).</p>') : ""}
      <p class="gesture">Toca la ficha para ver la respuesta<span class="keys"> · o pulsa <kbd>Espacio</kbd></span></p>`;
  } else {
    const p = c.previews || { again: 1, hard: 1, good: 3, easy: 7 };
    body = (enOnly
      ? `${c.definition ? `<p class="def">${esc(c.definition)}</p>` : ""}<div><p class="ex tappable" data-slow="1" role="button" tabindex="0">${exHTML(c.example)}</p></div>
        ${c.hide_translation ? `<p class="es-line">${esPeek(`<span class="tr">${esc(c.translation)}</span><br><span class="ex-es">${esc(c.example_es)}</span>`)}</p>` : `<details class="es-peek"><summary>Ver en español</summary><p class="tr">${esc(c.translation)}</p><p class="ex-es">${esc(c.example_es)}</p></details>`}`
      : `${meaningHTML(c, "tr", false)}<div><p class="ex tappable" data-slow="1" role="button" tabindex="0">${exHTML(c.example)}</p>${c.hide_translation ? "" : `<p class="ex-es">${esc(c.example_es)}</p>`}</div>`) + `
      ${speakingBlock()}${aidBlock(c, c.fails >= 2 && !c.aid)}
      <div class="swipe-legend" aria-label="Califica deslizando la ficha">
        <span class="l tappable" role="button" tabindex="0" data-grade="again"><b>← Olvidé</b><small>${days(p.again)}</small></span>
        <span class="d tappable" role="button" tabindex="0" data-grade="hard"><b>↓ Difícil</b><small>${days(p.hard)}</small></span>
        <span class="r tappable" role="button" tabindex="0" data-grade="good"><b>Bien →</b><small>${days(p.good)}</small></span>
        <span class="u tappable" role="button" tabindex="0" data-grade="easy"><b>↑ Fácil</b><small>${days(p.easy)}</small></span>
      </div>
      <p class="keys">Teclado: <kbd>1</kbd> Olvidé · <kbd>2</kbd> Difícil · <kbd>3</kbd> Bien · <kbd>4</kbd> Fácil · <kbd>R</kbd> escuchar · <kbd>M</kbd> decir la frase</p>`;
  }
  main.innerHTML = `<div class="card swipeable" id="theCard"><span class="swipe-hint" id="swipeHint"></span><div class="card-top"></div><div class="card-body">${front}${body}</div></div>`;
  if ($("spk")) $("spk").onclick = () => say(c.word);
  if ($("hintBtn")) $("hintBtn").onclick = e => { e.stopPropagation(); showHint = true; render(); };
  bindCardGestures(c, isNew);
  if (isNew && !hf.on && autoSpoken !== c.id) { autoSpoken = c.id; say(c.word); }
  if ($("aid")) { let t; $("aid").oninput = e => { c.aid = e.target.value; $("aidState").textContent = "Guardando…"; clearTimeout(t); t = setTimeout(() => api(`/words/${c.id}/aid`, { method: "PUT", body: { aid: c.aid } }).then(() => $("aidState").textContent = "Guardado").catch(err => $("aidState").textContent = err.message), 700); }; }
  if ($("suggBtn")) $("suggBtn").onclick = () => suggest(c);
  main.querySelectorAll("[data-g]").forEach(b => b.onclick = () => act(() => api(`/words/${c.id}/review`, { method: "POST", body: { grade: b.dataset.g } })));
  main.querySelectorAll("[data-say]").forEach(b => b.onclick = () => practice(c, b.dataset.say));
  main.querySelectorAll("[data-slow]").forEach(b => b.onclick = e => { e.stopPropagation(); say(plain(c.example), true); });
  main.querySelectorAll("[data-grade]").forEach(b => b.onclick = e => { e.stopPropagation(); cardAction(c, isNew, b.dataset.grade); });
  main.querySelectorAll(".tappable[role=button]").forEach(el => el.onkeydown = e => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); e.stopPropagation(); el.click(); } });
}

// ===== Gestos y teclado sobre la ficha =====
let autoSpoken = null;
const GRADE_BY_DIR = { left: "again", down: "hard", right: "good", up: "easy" };
function cardAction(c, isNew, action) {
  if (hf.on) return; // en manos libres decide la voz
  if (isNew) {
    if (action === "learn") act(() => api(`/words/${c.id}/learn`, { method: "POST" }), pick(PRAISE.learn));
  } else if (!revealed) {
    if (action === "reveal") { revealed = true; render(); say(c.word); }
  } else if (GRADE_BY_DIR[action] || ["again", "hard", "good", "easy"].includes(action)) {
    const g = GRADE_BY_DIR[action] || action;
    act(() => api(`/words/${c.id}/review`, { method: "POST", body: { grade: g } }), pick(PRAISE[g] || PRAISE.good));
  }
}
function bindCardGestures(c, isNew) {
  const el = $("theCard"), hint = $("swipeHint"); if (!el) return;
  const interactive = t => t.closest("button, a, input, textarea, select, label, .tappable, .drill, .sugg, details");
  // Toque simple: muestra la respuesta en los repasos.
  el.addEventListener("click", e => { if (!interactive(e.target) && !isNew && !revealed) cardAction(c, isNew, "reveal"); });
  const canSwipe = () => isNew || revealed;
  let sx = 0, sy = 0, dx = 0, dy = 0, dragging = false, id = null, touch = false;
  el.addEventListener("pointerdown", e => {
    if (!canSwipe() || interactive(e.target) || e.button > 0) return;
    dragging = true; id = e.pointerId; touch = e.pointerType === "touch"; sx = e.clientX; sy = e.clientY; dx = dy = 0; el.classList.add("dragging");
  });
  el.addEventListener("pointermove", e => {
    if (!dragging || e.pointerId !== id) return;
    dx = e.clientX - sx; dy = e.clientY - sy;
    if (Math.abs(dx) > 8 || Math.abs(dy) > 8) { try { el.setPointerCapture(id); } catch (err) {} }
    if (touch && Math.abs(dy) > Math.abs(dx)) { dx = 0; return; }
    const dir = swipeDir(dx, dy, isNew);
    el.style.transform = `translate(${dx}px, ${isNew ? 0 : dy * 0.6}px) rotate(${dx / 30}deg)`;
    const labels = isNew ? { right: ["La tengo", "var(--good)"] } : { left: ["Olvidé", "var(--bad)"], down: ["Difícil", "var(--warn)"], right: ["Bien", "var(--good)"], up: ["Fácil", "var(--accent)"] };
    const l = dir && labels[dir];
    hint.textContent = l ? l[0] : ""; hint.style.color = l ? l[1] : ""; hint.style.opacity = l ? Math.min(1, Math.max(Math.abs(dx), Math.abs(dy)) / 110) : 0;
    hint.style.left = dx < 0 ? "auto" : "14px"; hint.style.right = dx < 0 ? "14px" : "auto";
  });
  const end = e => {
    if (!dragging || (e && e.pointerId !== id)) return;
    dragging = false; el.classList.remove("dragging");
    if (touch) dy = 0;
    const dir = swipeDir(dx, dy, isNew), far = Math.max(Math.abs(dx), Math.abs(dy)) > 90;
    if (dir && far) {
      const ox = dir === "left" ? -600 : dir === "right" ? 600 : 0, oy = dir === "up" ? -500 : dir === "down" ? 500 : 0;
      el.style.transform = `translate(${ox}px, ${oy}px) rotate(${ox / 30}deg)`;
      setTimeout(() => cardAction(c, isNew, isNew ? "learn" : dir), 160);
    } else { el.style.transform = ""; hint.style.opacity = 0; }
  };
  el.addEventListener("pointerup", end); el.addEventListener("pointercancel", end);
}
function swipeDir(dx, dy, isNew) {
  if (isNew) return dx > 0 ? "right" : null;
  if (Math.abs(dx) >= Math.abs(dy)) return dx > 0 ? "right" : dx < 0 ? "left" : null;
  return dy > 0 ? "down" : "up";
}
document.addEventListener("keydown", e => {
  if (e.metaKey || e.ctrlKey || e.altKey || hf.on) return;
  if (e.target.closest && e.target.closest("input, textarea, select, [contenteditable]")) return;
  if ($("appView").hidden || $("main").hidden || !$("quizView").hidden) return;
  const c = cards[0]; if (!c) return;
  const isNew = c.mode === "new", k = e.key.toLowerCase();
  const map = { " ": isNew ? null : "reveal", enter: isNew ? "learn" : (revealed ? "good" : "reveal"), "1": "again", "2": "hard", "3": "good", "4": "easy" };
  if (k === "r") { e.preventDefault(); say(c.word); return; }
  if (k === "m" && (isNew || revealed)) { e.preventDefault(); practice(c, "sentence"); return; }
  if (k === "h" && !isNew && !revealed && c.aid) { e.preventDefault(); showHint = true; render(); return; }
  const a = map[k]; if (!a) return;
  if (["again", "hard", "good", "easy"].includes(a) && (isNew || !revealed)) return;
  e.preventDefault(); cardAction(c, isNew, a);
});
async function act(fn, praise) {
  document.querySelectorAll("#main button").forEach(b => b.disabled = true);
  try { await fn(); if (praise) toast(praise); cards.shift(); revealed = false; showHint = false; render(); stats = await api("/stats"); renderSide(); }
  catch (e) { $("main").insertAdjacentHTML("afterbegin", '<p class="warnbox">' + esc(e.message) + "</p>"); document.querySelectorAll("#main button").forEach(b => b.disabled = false); }
}
async function suggest(c) {
  $("sugg").innerHTML = '<p class="note">Pensando escenas absurdas…</p>';
  try {
    const r = await api(`/words/${c.id}/aid/suggest`, { method: "POST" });
    $("sugg").innerHTML = r.suggestions.map((l, i) => `<button type="button" data-pick="${i}">${esc(l)}</button>`).join("") + '<p class="hint">Toca una para usarla. Mejor aún: edítala a tu manera.</p>';
    $("sugg").querySelectorAll("[data-pick]").forEach(b => b.onclick = () => { $("aid").value = r.suggestions[+b.dataset.pick]; $("aid").dispatchEvent(new Event("input")); });
  } catch (e) { $("sugg").innerHTML = '<p class="note">' + esc(e.message) + "</p>"; }
}

// ===== Speaking =====
async function practice(c, target) {
  const ref = target === "word" ? c.word : plain(c.example), out = $("heard");
  const btns = document.querySelectorAll("[data-say]"); btns.forEach(b => b.disabled = true);
  try {
    if (cfg.pronunciation) {
      out.innerHTML = '<span class="score rec">Grabando… di:</span> <b>' + esc(ref) + '</b> <button type="button" id="stopRec">Listo</button>';
      $("stopRec").onclick = () => stopRecording && stopRecording();
      const wav = await recordWav(target === "word" ? 2500 : 7000, null, target === "word" ? 0.5 : 1.0);
      out.innerHTML = '<span class="note">Evaluando tu pronunciación…</span>';
      const fd = new FormData(); fd.append("target", target); fd.append("audio", wav, "voz.wav");
      const r = await api(`/words/${c.id}/pronunciation`, { method: "POST", body: fd });
      showAzure(r, out);
      if (target === "word") c.best_pron_score = Math.max(c.best_pron_score || 0, r.score);
      if (target === "sentence") startDrill(c, weakFromAzure(r.assessment));
    } else {
      out.innerHTML = '<span class="score rec">Escuchando… di:</span> <b>' + esc(ref) + "</b>";
      const alts = await browserListen(); let best = null, bt = "";
      alts.forEach(a => { const r = compare(ref, a); if (!best || r.pct > best.pct) { best = r; bt = a; } });
      verdict(out, best.pct, '<span class="note">Entendí: “' + esc(bt) + '”</span>', best.toks.map(z => `<span class="tok ${z.ok ? "ok" : "miss"}">${esc(z.x)}</span>`).join(""));
      api(`/words/${c.id}/pronunciation`, { method: "POST", body: { target, score: best.pct } }).catch(() => {});
      if (target === "sentence") startDrill(c, best.toks.filter(z => !z.ok).map(z => z.x));
    }
  } catch (e) { out.innerHTML = '<p class="warnbox">' + esc(e.message || "No se pudo usar el micrófono.") + "</p>"; }
  btns.forEach(b => b.disabled = false);
}
function verdict(out, pct, extra, tokens) {
  const v = pct >= 90 ? "Excelente" : pct >= 70 ? "Casi" : "Otra vez", col = pct >= 90 ? "var(--good)" : pct >= 70 ? "var(--warn)" : "var(--bad)";
  out.innerHTML = `<div class="row"><b class="score" style="color:${col}">${v} · ${pct}%</b>${extra}</div><div>${tokens}</div>` + (pct < 90 ? '<p class="hint">Lo marcado en rojo necesita práctica. Abajo te explico cómo decir cada palabra.</p>' : "");
}
function showAzure(r, out) {
  const a = r.assessment;
  if (!a || a.status !== "Success") { out.innerHTML = '<p class="note">No se entendió el audio. Habla un poco más fuerte y cerca del micrófono.</p>'; return; }
  const s = a.scores;
  const toks = a.words.map(w => {
    const ok = w.error === "None" && w.accuracy >= 80;
    const ph = w.phonemes.length ? `<span class="ph">/${w.phonemes.map(p => `<i class="${p.accuracy < 60 ? "bad" : ""}" title="${p.accuracy}%">${esc(p.phoneme)}</i>`).join("")}/</span>` : "";
    const tag = w.error === "Omission" ? " (omitida)" : w.error === "Insertion" ? " (de más)" : "";
    return `<span class="tok ${ok ? "ok" : "miss"}">${esc(w.word)} ${w.accuracy}%${tag}</span>${ok ? "" : ph}`;
  }).join(" ");
  verdict(out, s.pron, `<span class="scores"><span>Precisión ${s.accuracy}</span><span>Fluidez ${s.fluency}</span><span>Completitud ${s.completeness}</span></span>`, toks);
}

// ===== Técnicas de pronunciación para hispanohablantes =====
// Clave = fonema IPA (como lo devuelve Azure). "pair" = palabras de contraste para practicar.
const PRON_TIPS = {
  "θ": { name: "TH suave (think)", how: "Saca la punta de la lengua entre los dientes y sopla aire sin vibrar. No es “s” ni “t”.", pair: "think / sink · three / tree" },
  "ð": { name: "TH sonora (this)", how: "Lengua entre los dientes igual que en “think”, pero haciendo vibrar la garganta. Suena parecido a la “d” suave de “cada”.", pair: "they / day · then / den" },
  "v": { name: "V (very)", how: "Apoya los dientes de arriba sobre el labio de abajo y haz vibrar. No juntes los labios: eso es “b”.", pair: "very / berry · vote / boat" },
  "b": { name: "B (boat)", how: "Junta los dos labios y suéltalos con fuerza. Diferénciala de la “v”, que usa dientes y labio.", pair: "ban / van · best / vest" },
  "ʃ": { name: "SH (she)", how: "Redondea los labios hacia adelante y deja salir el aire como cuando pides silencio: “shhh”.", pair: "she / see · ship / sip" },
  "tʃ": { name: "CH (check)", how: "Como la “ch” del español, pero con los labios un poco hacia adelante.", pair: "chip / ship · watch / wash" },
  "dʒ": { name: "J (job)", how: "Como “ch” pero haciendo vibrar la garganta. No es la “j” española ni la “y”.", pair: "job / yob · jet / yet" },
  "ʒ": { name: "Sonido de “usual”", how: "Como “sh” pero vibrando la garganta, parecido a la “ll” rioplatense.", pair: "usual · vision · measure" },
  "z": { name: "Z inglesa (zoo, is)", how: "Es una “s” que vibra: pon la mano en el cuello y siente el zumbido. La “s” final de “is”, “was” y “has” suena así.", pair: "zoo / sue · prize / price" },
  "h": { name: "H aspirada (house)", how: "Solo aire suave desde la garganta, como empañar un espejo. No la raspes como la “j” española.", pair: "hat / at · hold / old" },
  "ɹ": { name: "R inglesa (red)", how: "Curva la lengua hacia atrás sin tocar el paladar y redondea un poco los labios. No vibra como la “r” española.", pair: "right / light · road / load" },
  "r": { name: "R inglesa (red)", how: "Curva la lengua hacia atrás sin tocar el paladar y redondea un poco los labios. No vibra como la “r” española.", pair: "right / light · road / load" },
  "ŋ": { name: "NG final (thing)", how: "Termina con la parte de atrás de la lengua contra el paladar, sin soltar una “g” al final.", pair: "thing / thin · sing / sin" },
  "j": { name: "Y (yes)", how: "Una “i” muy corta antes de la vocal. No la conviertas en “ll” ni en “j” inglesa.", pair: "yes / Jess · yet / jet" },
  "w": { name: "W (work)", how: "Empieza con los labios redondos como para decir “u” y ábrelos rápido. No pongas “g” delante.", pair: "would / good · west / guest" },
  "ɪ": { name: "I corta (ship)", how: "Más relajada y corta que la “i” española, casi entre “i” y “e”. La boca casi no sonríe.", pair: "ship / sheep · live / leave" },
  "i": { name: "I larga (sheep)", how: "Una “i” más larga y tensa, sonriendo un poco.", pair: "sheep / ship · seat / sit" },
  "æ": { name: "A abierta (cat)", how: "Abre mucho la boca, como para “a”, pero estira los labios como para “e”. Queda entre las dos.", pair: "cat / cut · bad / bed" },
  "ʌ": { name: "A corta (cup)", how: "Una “a” breve y relajada, con la boca medio abierta, sin tensión.", pair: "cup / cap · luck / lock" },
  "ə": { name: "Vocal neutra (about)", how: "Una vocal muy débil y corta, casi un murmullo “uh”. Las sílabas sin acento casi siempre suenan así.", pair: "about · banana · problem" },
  "ɑ": { name: "A larga (car)", how: "Abre la boca grande y baja la lengua, como cuando el médico te pide “aaa”.", pair: "hot · father · stop" },
  "ɔ": { name: "O abierta (law)", how: "Labios redondos y boca abierta, una “o” más larga y profunda que la española.", pair: "law / low · caught / coat" },
  "ʊ": { name: "U corta (book)", how: "Una “u” relajada y corta, sin redondear mucho los labios.", pair: "full / fool · look / Luke" },
  "u": { name: "U larga (food)", how: "Una “u” larga con los labios bien redondos hacia adelante.", pair: "fool / full · pool / pull" },
  "oʊ": { name: "O deslizada (go)", how: "Empieza en “o” y termina cerrando los labios hacia “u”: “ou”.", pair: "go · phone · know" },
  "eɪ": { name: "E deslizada (day)", how: "Empieza en “e” y termina en una “i” suave: “ei”.", pair: "day · late · rate" },
  "ɜ": { name: "ER (work)", how: "Lengua en el centro de la boca y un poco hacia atrás, labios relajados; suena “er” sin vibrar.", pair: "work / walk · bird / bud" },
  "ɝ": { name: "ER (work)", how: "Lengua en el centro de la boca y un poco hacia atrás, labios relajados; suena “er” sin vibrar.", pair: "work / walk · bird / bud" },
  "t": { name: "T final", how: "Pronuncia la “t” al final aunque sea suave; si la quitas, cambia la palabra (“bet” y “bed”).", pair: "bet / bed · cart / car" },
  "d": { name: "D final", how: "Haz vibrar la garganta al final: la vocal antes de “d” se alarga un poco.", pair: "bed / bet · need / neat" },
  "s": { name: "S", how: "Una “s” clara y sin vibración. Al inicio con consonante (speak, start) no pongas “e” delante.", pair: "speak · school · start" }
};

// Pistas por ortografía, para el modo navegador (sin detalle de sonidos).
function spellingTips(word) {
  const w = word.toLowerCase(), out = [];
  if (/th/.test(w)) out.push(/^(the|this|that|these|those|they|them|then|there|than|though)$/.test(w) ? "ð" : "θ");
  if (/v/.test(w)) out.push("v");
  if (/sh|tion|sion/.test(w)) out.push("ʃ");
  if (/^s[ptkcmnlw]/.test(w)) out.push("s");
  if (/^h/.test(w) && !/^(hour|honest)/.test(w)) out.push("h");
  if (/r/.test(w)) out.push("ɹ");
  if (/ng$/.test(w)) out.push("ŋ");
  if (/^(w|wh)/.test(w)) out.push("w");
  if (/z|[^s]s$/.test(w) && /^(is|was|has|does|goes|his|hers)$/.test(w)) out.push("z");
  if (/[td]$/.test(w)) out.push(w.endsWith("t") ? "t" : "d");
  return out;
}
function tipsHtml(word, badPhonemes) {
  const keys = [];
  (badPhonemes || []).forEach(p => { const k = PRON_TIPS[p] ? p : PRON_TIPS[p.replace("ː", "")] ? p.replace("ː", "") : null; if (k && !keys.includes(k)) keys.push(k); });
  if (!keys.length) spellingTips(word).forEach(k => { if (!keys.includes(k)) keys.push(k); });
  const items = keys.slice(0, 3).map(k => { const t = PRON_TIPS[k]; return `<li><b>${esc(t.name)}</b><span class="how">${esc(t.how)}</span><span class="pair">Practica: ${esc(t.pair)}</span></li>`; });
  const general = `<li><b>Técnica: lento → normal</b><span class="how">Escúchala lenta, dila separando sílabas, y luego 3 veces seguidas a velocidad normal. Exagera la boca al principio.</span></li>`;
  return `<span class="label">Cómo decirla</span><ul class="tips">${items.join("") || general}${items.length ? general : ""}</ul>`;
}

// ===== Repaso de palabras mal pronunciadas =====
// Después de decir una frase, las palabras falladas se practican una por una
// hasta decirlas bien; al final se pide repetir la frase completa.
const DRILL_PASS = 80, DRILL_SKIP_AFTER = 3;
let drill = null;
function weakFromAzure(a) {
  if (!a || a.status !== "Success") return [];
  const weak = a.words.filter(w => w.error !== "Insertion" && (w.error !== "None" || w.accuracy < DRILL_PASS));
  weakFromAzure.phonemes = weak.map(w => w.phonemes.filter(p => p.accuracy < 60).map(p => p.phoneme).filter(Boolean));
  return weak.map(w => w.word);
}
function startDrill(c, words) {
  const seen = new Set(), list = [];
  const phon = cfg.pronunciation && weakFromAzure.phonemes ? weakFromAzure.phonemes : [], bad = [];
  words.forEach((w, idx) => { const k = norm(w).join(" "), shown = String(w).toLowerCase().replace(/’/g, "'").replace(/[^a-z' -]/g, "").trim(); if (k && shown && !seen.has(k)) { seen.add(k); list.push(shown); bad.push(phon[idx] || []); } });
  const box = $("drill"); if (!box) return;
  if (!list.length) { drill = null; box.innerHTML = ""; return; }
  drill = { c, words: list, done: [], i: 0, tries: 0, bad };
  weakFromAzure.phonemes = null;
  renderDrill();
}
function renderDrill(msg) {
  const box = $("drill"); if (!box || !drill) return;
  const d = drill;
  if (d.i >= d.words.length) {
    box.className = "drill done";
    box.innerHTML = `<h4>¡Bien! Ya dijiste bien todas las palabras.</h4>
      <p class="note">Ahora repite la frase completa para fijarla.</p>
      <div class="row"><button type="button" class="primary" id="drillSentence">${ICON_MIC} Decir la frase otra vez</button></div>`;
    $("drillSentence").onclick = () => { box.innerHTML = ""; drill = null; practice(d.c, "sentence"); };
    return;
  }
  const w = d.words[d.i];
  const queue = d.words.map((x, k) => `<span class="tok ${k < d.i ? (d.done[k] ? "ok" : "miss") : "miss"} ${k === d.i ? "now" : ""}">${esc(x)}</span>`).join("");
  box.className = "drill";
  box.innerHTML = `<h4>Practica las palabras que fallaste (${d.i + 1} de ${d.words.length})</h4>
    <div class="queue">${queue}</div>
    <p class="big">${esc(w)}</p>
    ${d.tries > 0 || (d.bad && d.bad[d.i]) ? tipsHtml(w, d.bad && d.bad[d.i]) : ""}
    <div class="row">
      <button type="button" class="icon" id="drillListen">${ICON_SPK} Escuchar lento</button>
      <button type="button" class="primary icon" id="drillSay">${ICON_MIC} Decirla</button>
      ${d.tries >= DRILL_SKIP_AFTER ? '<button type="button" id="drillSkip">Saltar por ahora</button>' : ""}
    </div>
    <div class="res" id="drillRes">${msg || '<span class="note">Escúchala, luego dila en voz alta. No pasamos a la siguiente hasta que te salga bien.</span>'}</div>`;
  $("drillListen").onclick = () => say(w, true);
  $("drillSay").onclick = () => drillAttempt();
  if ($("drillSkip")) $("drillSkip").onclick = () => { d.done[d.i] = false; d.i++; d.tries = 0; renderDrill(); };
}
async function drillAttempt() {
  const d = drill; if (!d) return;
  const w = d.words[d.i], res = $("drillRes");
  document.querySelectorAll("#drill button").forEach(b => b.disabled = true);
  let ok = false, detail = "";
  try {
    if (cfg.pronunciation) {
      res.innerHTML = '<span class="score rec">Grabando… di:</span> <b>' + esc(w) + '</b> <button type="button" id="drillStop">Listo</button>';
      $("drillStop").onclick = () => stopRecording && stopRecording();
      const wav = await recordWav(2500, null, 0.5);
      res.innerHTML = '<span class="note">Evaluando…</span>';
      const fd = new FormData(); fd.append("target", "text"); fd.append("text", w); fd.append("audio", wav, "voz.wav");
      const r = await api(`/words/${d.c.id}/pronunciation`, { method: "POST", body: fd });
      const a = r.assessment, aw = a && a.status === "Success" ? a.words.find(x => x.error !== "Insertion") : null;
      if (!aw) { detail = "No se entendió el audio. Habla un poco más fuerte."; }
      else {
        ok = aw.error === "None" && aw.accuracy >= DRILL_PASS;
        const bad = aw.phonemes.filter(p => p.accuracy < 60).map(p => p.phoneme).filter(Boolean);
        d.bad = d.bad || []; d.bad[d.i] = bad;
        detail = `${aw.accuracy}%` + (bad.length ? ` · sonidos a mejorar: /${bad.map(esc).join("/, /")}/` : "");
      }
    } else {
      res.innerHTML = '<span class="score rec">Escuchando… di:</span> <b>' + esc(w) + "</b>";
      const alts = await browserListen();
      ok = alts.some(x => (" " + norm(x).join(" ") + " ").includes(" " + norm(w).join(" ") + " "));
      detail = "Entendí: “" + esc(alts[0] || "") + "”";
    }
  } catch (e) { detail = esc(e.message || "No se pudo usar el micrófono."); }
  if (ok) {
    d.done[d.i] = true; d.i++; d.tries = 0;
    renderDrill(`<b style="color:var(--good)">¡Bien dicha!</b> <span class="note">${detail}</span>`);
  } else {
    d.tries++;
    renderDrill(`<b style="color:var(--bad)">Otra vez</b> <span class="note">${detail}</span> <span class="note">Escúchala lento e imita cada sonido.</span>`);
  }
}

// ===== Conversación =====
let history = [];
function renderChat(targets, used) {
  if (targets) $("targets").innerHTML = targets.map(t => `<span class="chip ${used && used.has(t.toLowerCase()) ? "used" : ""}">${esc(t)}</span>`).join("");
  $("msgs").innerHTML = history.map(m => `<div class="msg ${m.role === "user" ? "me" : "ai"}">${esc(m.content)}${m.feedback ? `<p class="fb">${esc(m.feedback)} ${esTranslate(m.feedback)}</p>` : ""}</div>`).join("") || '<p class="note">Pulsa Enviar con el campo vacío para que la IA empiece.</p>';
  $("msgs").scrollTop = $("msgs").scrollHeight;
}
const usedWords = new Set();
async function sendChat() {
  if (!cfg.ai) { $("msgs").innerHTML = '<p class="warnbox">La conversación necesita ANTHROPIC_API_KEY en el servidor.</p>'; return; }
  const text = $("chatIn").value.trim();
  if (text) history.push({ role: "user", content: text });
  $("chatIn").value = ""; $("sendBtn").disabled = true; renderChat();
  try {
    const r = await api("/conversation", { method: "POST", body: { messages: history.map(({ role, content }) => ({ role, content })) } });
    const lastUser = [...history].reverse().find(m => m.role === "user");
    if (lastUser && r.feedback) lastUser.feedback = r.feedback;
    (r.used || []).forEach(w => usedWords.add(w.toLowerCase()));
    history.push({ role: "assistant", content: r.reply });
    renderChat(r.targets, usedWords);
    if ($("autoSpeak").checked) say(r.reply);
  } catch (e) { $("msgs").insertAdjacentHTML("beforeend", '<p class="warnbox">' + esc(e.message) + "</p>"); }
  $("sendBtn").disabled = false;
}
$("sendBtn").onclick = sendChat;
$("chatIn").onkeydown = e => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); sendChat(); } };
$("chatReset").onclick = () => { history = []; usedWords.clear(); renderChat([]); };
$("dictBtn").onclick = async () => {
  $("dictBtn").classList.add("rec");
  try { const alts = await browserListen(); $("chatIn").value = ($("chatIn").value + " " + alts[0]).trim(); }
  catch (e) { $("msgs").insertAdjacentHTML("beforeend", '<p class="warnbox">' + esc(e.message) + "</p>"); }
  $("dictBtn").classList.remove("rec");
};
// Secciones. Abajo: today (Hoy), path (Camino), practice (Practicar), progress (Progreso).
// Dentro de Practicar: cards (fichas), speak (hablar), chat. true/false = chat/fichas (llamadas viejas).
const NAV_OF = { today: "today", path: "path", practice: "practice", progress: "progress", cards: "practice", speak: "practice", chat: "practice" };
let currentTab = "today";
function showTab(which) {
  which = which === true ? "chat" : which === false ? "cards" : which;
  if (which !== "cards" && hf.on) stopHF();
  if (which !== "speak" && typeof spLeave === "function") spLeave();
  currentTab = which;
  document.body.dataset.nav = which === "progress" ? "progress" : which === "cards" ? "cards" : NAV_OF[which];
  if ($("labView") && !$("labView").hidden) { lab.on = false; if (stopRecording) stopRecording(); $("labView").hidden = true; }
  $("tabCards").setAttribute("aria-selected", which === "cards"); $("tabChat").setAttribute("aria-selected", which === "chat"); $("tabSpeak").setAttribute("aria-selected", which === "speak"); $("tabProgress").setAttribute("aria-selected", which === "progress");
  $("main").hidden = which !== "cards"; $("queue").hidden = which !== "cards"; $("chatView").hidden = which !== "chat"; $("speakView").hidden = which !== "speak"; $("progressView").hidden = which !== "progress";
  $("todayView").hidden = which !== "today"; $("pathView").hidden = which !== "path"; $("practiceView").hidden = which !== "practice";
  document.querySelectorAll("#bottomNav [data-nav]").forEach(b => b.toggleAttribute("aria-current", false) || (b.dataset.nav === NAV_OF[which] && b.setAttribute("aria-current", "page")));
  if (which === "chat") renderChat();
  if (which === "speak" && typeof spOpen === "function") spOpen();
  if (which === "progress" && typeof pgOpen === "function") pgOpen();
  if (which === "today" && typeof tdOpen === "function") tdOpen();
  if (which === "practice" && typeof prOpen === "function") prOpen();
  if (which === "path" && typeof pathOpen === "function") pathOpen();
  window.scrollTo({ top: 0 });
}
$("tabCards").onclick = () => showTab("cards");
$("tabChat").onclick = () => showTab("chat");
$("tabSpeak").onclick = () => showTab("speak");
$("tabProgress").onclick = () => showTab("progress");
document.querySelectorAll("#bottomNav [data-nav]").forEach(b => b.onclick = () => { unlockAudio(); showTab(b.dataset.nav); });

// ===== Panel lateral y ajustes =====
function renderSide() {
  if (!stats) return;
  $("sLearned").textContent = stats.learned; $("sMastered").textContent = stats.mastered; $("sStreak").textContent = stats.streak;
  $("streakChip").hidden = !stats.streak; $("streakChip").innerHTML = ICON_FLAME + stats.streak + (stats.streak === 1 ? " día" : " días");
  $("sLeft").textContent = `${stats.total_words - stats.learned} palabras por aprender de ${stats.total_words}.`;
  const max = Math.max(1, ...stats.forecast.map(x => x.count));
  $("forecast").innerHTML = stats.forecast.map((x, i) => { const d = new Date(x.date + "T12:00"); const lbl = i === 0 ? "mañana" : d.toLocaleDateString("es", { weekday: "short", day: "numeric" }); return `<div class="fc-row"><span class="lbl">${lbl}</span><span class="fc-bar"><i style="width:${x.count / max * 100}%"></i></span><span class="n">${x.count}</span></div>`; }).join("");
  $("weakNote").hidden = !!stats.weak_sounds.length;
  $("weak").innerHTML = stats.weak_sounds.map(w => `<button type="button" class="chip" data-ph="${esc(w.phoneme)}" title="Practicar · último: ${esc(w.last_word)}">/${esc(w.phoneme)}/ × ${w.count}</button>`).join("");
  $("weak").querySelectorAll("[data-ph]").forEach(b => b.onclick = () => { unlockAudio(); openLab(b.dataset.ph); });
}
// Comparar la voz de Azure con la voz local (Kokoro): la misma frase con cada una.
async function compareVoice(provider) {
  unlockAudio();
  const st = $("voiceCmpState"); st.textContent = "Generando…";
  try {
    const res = await fetch(API + "/tts?" + new URLSearchParams({ text: "Hi! I'm your English partner. How was your day today?", lang: "en", provider }), { headers: { Accept: "audio/mpeg", Authorization: "Bearer " + token } });
    if (!res.ok) throw new Error(provider === "kokoro" ? "La voz local no está encendida (tts-local/Arrancar voz local.command)." : "Azure no respondió.");
    ttsAudio.src = URL.createObjectURL(await res.blob()); await ttsAudio.play(); st.textContent = "";
  } catch (e) { st.textContent = e.message; }
}
$("cmpAzure").onclick = () => compareVoice("azure");
$("cmpKokoro").onclick = () => compareVoice("kokoro");
// Elegir micrófono (p. ej. el del iPhone aunque tengas AirPods puestos).
async function renderMicSelect() {
  const sel = $("micSel"); if (!sel) return;
  const mics = await listMics();
  sel.innerHTML = `<option value="">Automático</option>` + mics.map((m, i) => `<option value="${esc(m.deviceId)}"${m.deviceId === mic.pref ? " selected" : ""}>${esc(m.label || "Micrófono " + (i + 1))}</option>`).join("");
  $("micNote").textContent = mics.some(m => m.label) ? "" : "Usa el micrófono una vez (en Hablar o en una ficha) para ver los nombres.";
}
$("micSel").onchange = e => { mic.pref = e.target.value; try { localStorage.setItem("wtw_mic", mic.pref); } catch (er) {} releaseMic(); };
$("micSel").onfocus = renderMicSelect;
$("speakGoal").onchange = async e => { try { await api("/speaking/goal", { method: "PUT", body: { speaking_goal: Math.max(1, Math.min(60, +e.target.value || 5)) } }); if (typeof spRefreshStats === "function") spRefreshStats(); } catch (err) { alertSide(err.message); } };
$("dailyNew").onchange = async e => { try { await api("/settings", { method: "PUT", body: { daily_new: +e.target.value } }); refresh(); } catch (err) { alertSide(err.message); } };
async function nextDay() { try { await api("/debug/next-day", { method: "POST" }); refresh(); } catch (e) { alertSide(e.message); } }
$("nextDay").onclick = nextDay;
$("resetBtn").onclick = () => { $("confirmBox").hidden = false; $("resetPass").focus(); };
$("resetNo").onclick = () => { $("confirmBox").hidden = true; $("resetPass").value = ""; $("resetMsg").textContent = ""; };
// Borrar la cuenta y todo lo que tiene (también desde /cuenta/borrar/).
$("delAccBtn").onclick = () => { $("delAccBox").hidden = false; $("delAccPass").focus(); };
$("delAccNo").onclick = () => { $("delAccBox").hidden = true; $("delAccPass").value = ""; $("delAccMsg").textContent = ""; };
$("delAccYes").onclick = async () => {
  $("delAccYes").disabled = true; $("delAccMsg").textContent = "Borrando…";
  try {
    await api("/account", { method: "DELETE", body: { password: $("delAccPass").value } });
    setToken(null); profile = null; applyUiLang(); showAuth(); setAuthMode("login");
  } catch (e) { $("delAccMsg").textContent = e.message; }
  $("delAccYes").disabled = false;
};
$("resetYes").onclick = async () => {
  $("resetYes").disabled = true; $("resetMsg").textContent = "Borrando…";
  try {
    await api("/reset", { method: "POST", body: { password: $("resetPass").value } });
    $("confirmBox").hidden = true; $("resetPass").value = ""; $("resetMsg").textContent = ""; refresh();
  } catch (e) { $("resetMsg").textContent = e.message; }
  $("resetYes").disabled = false;
};
function alertSide(m) { $("svc").textContent = m; }

// ===== Perfil, verificación de correo =====
let profile = null, levelsData = null;
function renderBanners(extra) {
  const box = $("banners"); if (!box) return;
  let html = extra || "";
  if (profile && profile.demo) {
    html += `<div class="banner"><p><b>Estás en la demo.</b> Este alumno de ejemplo (nivel B1, con 3 semanas de historial) es solo para ti y se borra en 24 horas.</p><button type="button" id="demoSignup">Crear mi cuenta</button></div>`;
  }
  if (profile && !profile.email_verified && !profile.demo) {
    html += `<div class="banner"><p>Confirma tu correo <b>${esc(profile.email)}</b> para poder recuperar tu cuenta si olvidas la contraseña.</p><button type="button" id="resendBtn">Reenviar correo</button></div>`;
  }
  box.innerHTML = html;
  if ($("demoSignup")) $("demoSignup").onclick = async () => { try { await api("/auth/logout", { method: "POST" }); } catch (e) {} setToken(null); profile = null; showAuth(); setAuthMode("register"); };
  if ($("resendBtn")) $("resendBtn").onclick = async () => {
    const b = $("resendBtn"); b.disabled = true;
    try { const r = await api("/email/verification-notification", { method: "POST" }); b.textContent = "Enviado"; alertSide(r.message); }
    catch (e) { b.disabled = false; alertSide(e.message); }
  };
}

// ===== Niveles MCER =====
async function loadLevels() {
  try { levelsData = await api("/levels"); } catch (e) { $("levelBox").innerHTML = '<p class="note">' + esc(e.message) + "</p>"; return; }
  renderLevel();
}
function renderLevel() {
  const box = $("levelBox"), d = levelsData; if (!d) return;
  const codes = d.levels.map(l => l.code), cur = d.current, curIdx = codes.indexOf(cur);
  $("lvlChip").hidden = !cur; $("lvlChip").textContent = cur ? "Nivel " + cur : "";
  const path = `<ul class="path">${d.levels.map((l, i) => {
    const st = !cur ? "" : i < curIdx ? "superado" : i === curIdx ? "actual" : (l.words ? "" : "sin palabras");
    return `<li class="${i < curIdx ? "done" : i === curIdx ? "cur" : ""}"><span class="code">${esc(l.code)}</span><span>${esc(l.name)}</span><span class="st">${st}</span></li>`;
  }).join("")}</ul>`;
  if (!cur) {
    box.innerHTML = `<p class="note">Haz la prueba de nivel para empezar donde te corresponde.</p><button type="button" class="primary" id="lvlStart">Hacer la prueba de nivel</button>${path}`;
    $("lvlStart").onclick = placementIntro; return;
  }
  const p = d.progress, pct = p.total ? Math.round(p.introduced / p.total * 100) : 0;
  const examInfo = !p.next ? '<p class="note">Estás en el último nivel. Sigue repasando para dominarlo.</p>'
    : p.total === 0 ? '<p class="warnbox">Todavía no hay palabras cargadas para este nivel. Importa la lista NGSL (<code>php artisan words:import</code>).</p>'
    : p.exam_ready ? `<button type="button" class="primary" id="examBtn">Examen para subir a ${esc(p.next)}</button>`
    : `<p class="note">Aprende ${p.exam_needed - p.introduced} palabras más para desbloquear el examen de ${esc(p.next)}.</p>`;
  box.innerHTML = `<div class="lvl-head"><span class="lvl-badge">${esc(cur)}</span><div><b>${esc(p.name)}</b><span>${p.introduced} de ${p.total} palabras · ${p.mastered} dominadas</span></div></div>
    <div class="bar" role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${pct}" aria-label="Progreso del nivel"><i style="width:${pct}%"></i></div>
    <div><p class="hint" style="margin-bottom:4px">Al terminar este nivel podrás:</p><ul class="can">${p.can.map(c => `<li>${esc(c)}</li>`).join("")}</ul></div>
    ${examInfo}
    <details><summary class="hint">Ver el camino completo</summary>${path}</details>`;
  if ($("examBtn")) $("examBtn").onclick = startExam;
}

// --- Vista de prueba (reemplaza las fichas mientras dura) ---
function showQuiz(on) {
  if (!on) { $("quizView").hidden = true; showTab("today"); return; }
  if (hf.on) stopHF();
  ["queue", "main", "hfBar", "hello", "chatView", "speakView", "progressView", "todayView", "pathView", "practiceView", "labView"].forEach(id => { if ($(id)) $(id).hidden = true; });
  $("quizView").hidden = false;
}
function placementIntro() {
  showQuiz(true);
  const opts = (levelsData ? levelsData.levels : []).map(l => `<option value="${esc(l.code)}">${esc(l.code)} · ${esc(l.name)}</option>`).join("");
  $("quizBody").innerHTML = `<div class="kind"><span>Prueba de nivel</span><span>unos 3 minutos</span></div>
    <h2 class="tr">¿Desde qué nivel empezamos?</h2>
    <p class="ex">Te mostraremos palabras de todos los niveles. Elige la traducción correcta; si no la sabes, elige “No la sé”. Así empiezas donde te corresponde y no repites lo que ya sabes.</p>
    <div class="row"><button type="button" class="primary" id="pStart">Empezar la prueba</button></div>
    <div class="section"><h3>O elige tu nivel</h3><div class="row"><select id="pLevel" aria-label="Nivel">${opts}</select><button type="button" id="pChoose">Empezar en este nivel</button></div></div>
    ${profile && profile.cefr_level ? '<button type="button" id="pCancel">Cancelar</button>' : ""}`;
  $("pStart").onclick = startPlacement;
  $("pChoose").onclick = async () => {
    try { await api("/levels/current", { method: "PUT", body: { level: $("pLevel").value } }); await finishQuiz(); }
    catch (e) { $("quizBody").insertAdjacentHTML("beforeend", '<p class="warnbox">' + esc(e.message) + "</p>"); }
  };
  if ($("pCancel")) $("pCancel").onclick = () => showQuiz(false);
}
async function startPlacement() {
  try { const r = await api("/levels/placement"); runQuiz("placement", r.questions); }
  catch (e) { $("quizBody").insertAdjacentHTML("beforeend", '<p class="warnbox">' + esc(e.message) + "</p>"); }
}
async function startExam() {
  showQuiz(true);
  $("quizBody").innerHTML = '<p class="note">Preparando el examen…</p>';
  try { const r = await api("/levels/exam"); runQuiz("exam", r.questions, r.level); }
  catch (e) { $("quizBody").innerHTML = '<p class="warnbox">' + esc(e.message) + '</p><button type="button" id="qBack">Volver</button>'; $("qBack").onclick = () => showQuiz(false); }
}
function runQuiz(kind, questions, level) {
  const answers = []; let i = 0;
  const title = kind === "placement" ? "Prueba de nivel" : "Examen de " + level;
  const draw = () => {
    const q = questions[i], pct = Math.round(i / questions.length * 100);
    $("quizBody").innerHTML = `<div class="kind"><span>${esc(title)}</span><span>${i + 1} de ${questions.length}</span></div>
      <div class="bar q-bar"><i style="width:${pct}%"></i></div>
      <div class="word-row"><p class="q-word">${esc(q.word)}</p><button type="button" class="round" id="qSay" aria-label="Escuchar">${ICON_SPK}</button></div>
      ${q.example ? `<p class="ex">${fmtEx(q.example)}</p>` : ""}
      <div class="opts">${q.options.map((o, k) => `<button type="button" data-o="${k}">${esc(o)}</button>`).join("")}<button type="button" data-o="-1">No la sé</button></div>`;
    $("qSay").onclick = () => say(q.word, false);
    $("quizBody").querySelectorAll("[data-o]").forEach(b => b.onclick = () => {
      const k = +b.dataset.o;
      answers.push({ word_id: q.word_id, answer: k < 0 ? "" : q.options[k] });
      i++; i < questions.length ? draw() : submit();
    });
  };
  const submit = async () => {
    $("quizBody").innerHTML = '<p class="note">Calificando…</p>';
    try {
      const r = await api(kind === "placement" ? "/levels/placement" : "/levels/exam", { method: "POST", body: { answers } });
      if (kind === "placement") {
        $("quizBody").innerHTML = `<div class="kind"><span>Resultado</span><span>${r.score}% de aciertos</span></div>
          <p class="result">${esc(r.level)}</p><p class="tr">Empiezas en el nivel ${esc(r.level)}.</p>
          <p class="ex">Tus palabras nuevas empezarán desde este nivel. Cuando aprendas la mayoría, podrás presentar el examen para subir.</p>
          <div class="row"><button type="button" class="primary" id="qDone">Empezar a estudiar</button></div>`;
      } else {
        const missed = r.missed.length ? `<div class="section"><h3>Repasa estas palabras</h3><div class="row">${r.missed.map(m => `<span class="chip" title="${esc(m.translation)}">${esc(m.word)} · ${esc(m.translation)}</span>`).join("")}</div></div>` : "";
        $("quizBody").innerHTML = `<div class="kind"><span>Examen de ${esc(level)}</span><span>${r.score}% de aciertos</span></div>
          <p class="result">${r.passed ? "¡Subiste a " + esc(r.level) + "!" : "Casi"}</p>
          <p class="ex">${r.passed ? "Tus palabras nuevas ahora vienen del nivel " + esc(r.level) + "." : "Necesitas un " + Math.round((cfg.exam_pass || 0.8) * 100) + "% para subir. Repasa las palabras que fallaste y vuelve a intentarlo."}</p>
          ${missed}<div class="row"><button type="button" class="primary" id="qDone">Volver a estudiar</button></div>`;
      }
      $("qDone").onclick = finishQuiz;
    } catch (e) { $("quizBody").innerHTML = '<p class="warnbox">' + esc(e.message) + '</p><button type="button" id="qBack">Volver</button>'; $("qBack").onclick = () => showQuiz(false); }
  };
  draw();
}
async function finishQuiz() {
  try { profile = await api("/me"); } catch (e) {}
  applyUiLang();
  showQuiz(false);
  await loadLevels();
  await refresh();
}
function fmtEx(t) { return esc(t).replace(/\*([^*]+)\*/g, "<em>$1</em>"); }

// ===== Ajustes: paquete freelance y recordatorios =====
function renderSettings() {
  if (!profile) return;
  $("freelancePack").checked = !!profile.freelance_pack;
  $("speakGoal").value = profile.speaking_goal || 5;
  $("voiceCmp").hidden = !cfg.tts_local;   // comparar voces solo si la voz local está configurada
  renderMicSelect();
  $("remOn").checked = !!profile.reminder.enabled;
  $("remTime").value = profile.reminder.time || "19:00";
  $("remTime").disabled = !profile.reminder.enabled;
  $("remMsg").textContent = profile.reminder.enabled ? "Te avisaremos a las " + profile.reminder.time + " si no has estudiado." : "";
}
$("freelancePack").onchange = async e => {
  try { profile = await api("/settings", { method: "PUT", body: { freelance_pack: e.target.checked } }); refresh(); }
  catch (err) { e.target.checked = !e.target.checked; alertSide(err.message); }
};
function b64ToUint8(b64) { const pad = "=".repeat((4 - b64.length % 4) % 4), raw = atob((b64 + pad).replace(/-/g, "+").replace(/_/g, "/")); return Uint8Array.from([...raw].map(c => c.charCodeAt(0))); }
function pushProblem() {
  const ios = /iPhone|iPad|iPod/.test(navigator.userAgent);
  const standalone = window.matchMedia("(display-mode: standalone)").matches || navigator.standalone === true;
  if (ios && !standalone) return "En el iPhone, primero instala la app: Compartir → Agregar a pantalla de inicio. Luego actívalo desde la app instalada.";
  if (!("serviceWorker" in navigator) || !("PushManager" in window) || !("Notification" in window)) return "Este navegador no permite notificaciones.";
  if (!cfg.push) return "Las notificaciones todavía no están configuradas en el servidor.";
  return null;
}
async function subscribePush() {
  const problem = pushProblem(); if (problem) throw new Error(problem);
  const perm = await Notification.requestPermission();
  if (perm !== "granted") throw new Error("No diste permiso para notificaciones. Actívalo en los ajustes del navegador.");
  const { public_key } = await api("/push/key");
  const reg = await navigator.serviceWorker.ready;
  let sub = await reg.pushManager.getSubscription();
  if (!sub) sub = await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: b64ToUint8(public_key) });
  const j = sub.toJSON();
  await api("/push/subscriptions", { method: "POST", body: { endpoint: j.endpoint, keys: j.keys, contentEncoding: (PushManager.supportedContentEncodings || ["aes128gcm"])[0] } });
}
async function unsubscribePush() {
  try {
    const reg = await navigator.serviceWorker.ready, sub = await reg.pushManager.getSubscription();
    if (sub) { await api("/push/subscriptions", { method: "DELETE", body: { endpoint: sub.endpoint } }).catch(() => {}); await sub.unsubscribe(); }
  } catch (e) {}
}
async function saveReminder(enabled) {
  profile = await api("/reminders", { method: "PUT", body: { enabled, time: $("remTime").value || "19:00", timezone: userTimezone() } });
  renderSettings();
}
$("remOn").onchange = async e => {
  const on = e.target.checked; e.target.disabled = true; $("remMsg").textContent = on ? "Activando…" : "";
  try { if (on) await subscribePush(); else await unsubscribePush(); await saveReminder(on); }
  catch (err) { e.target.checked = !on; $("remMsg").textContent = err.message; }
  e.target.disabled = false;
};
$("remTime").onchange = async () => { try { await saveReminder(true); } catch (err) { $("remMsg").textContent = err.message; } };

// ===== PWA: instalable en el iPhone =====
if ("serviceWorker" in navigator) { window.addEventListener("load", () => navigator.serviceWorker.register("/app/sw.js").catch(() => {})); }

// ===== Aviso para instalar la app =====
(function () {
  const ua = navigator.userAgent;
  const isIOS = /iPhone|iPad|iPod/.test(ua) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
  const isAndroid = /Android/i.test(ua);
  const standalone = window.navigator.standalone === true || window.matchMedia("(display-mode: standalone)").matches;
  const inAppBrowser = /FBAN|FBAV|Instagram|Line\/|WhatsApp|GSA\//.test(ua);
  const iosOtherBrowser = isIOS && /CriOS|FxiOS|EdgiOS/.test(ua);
  const KEY = "wtw_install_later";
  let snoozed = false; try { snoozed = Date.now() < +(localStorage.getItem(KEY) || 0); } catch (e) {}
  if (standalone || snoozed || !(isIOS || isAndroid)) return;

  const bar = $("installBar"), body = $("installBody"), btn = $("installBtn");
  const SHARE = '<span class="sh" aria-label="Compartir"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v12M8 7l4-4 4 4"/><path d="M5 12v7a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-7"/></svg></span>';
  function show() { bar.hidden = false; document.body.classList.add("has-install"); }
  function hide(days) { bar.hidden = true; document.body.classList.remove("has-install"); if (days) { try { localStorage.setItem(KEY, Date.now() + days * 864e5); } catch (e) {} } }
  $("installLater").onclick = () => hide(3);

  if (isIOS) {
    if (inAppBrowser) {
      body.innerHTML = '<p class="note">Estás dentro de otra app. Abre este enlace en <b>Safari</b> para poder instalarla.</p>';
    } else {
      body.innerHTML = '<ol>' +
        '<li>Toca ' + SHARE + ' <b>Compartir</b> ' + (iosOtherBrowser ? "(arriba o en el menú)" : "en la barra de Safari") + '.</li>' +
        '<li>Elige <b>Agregar a pantalla de inicio</b>. Si no aparece, desliza la lista hacia abajo.</li>' +
        '<li>Toca <b>Agregar</b>. Ábrela siempre desde su ícono.</li></ol>';
      if (!iosOtherBrowser) $("installArrow").hidden = false;
    }
    show();
  } else {
    // Android / Chrome: el navegador permite instalar con un botón
    let deferred = null;
    window.addEventListener("beforeinstallprompt", e => {
      e.preventDefault(); deferred = e;
      body.innerHTML = '<p class="note">Agrégala a tu pantalla de inicio para abrirla como una app.</p>';
      btn.hidden = false; show();
    });
    btn.onclick = async () => { if (!deferred) return; deferred.prompt(); const r = await deferred.userChoice; deferred = null; hide(r.outcome === "accepted" ? 0 : 3); };
    window.addEventListener("appinstalled", () => hide(0));
  }
})();

// ===================== Familias de palabras =====================
let famData = null;
function famChip(c) { return c && c.family ? `<span class="fam-chip">${c.family.emoji} ${esc(c.family.label)}</span>` : ""; }
async function loadFamilies() {
  try { famData = await api("/families"); } catch (e) { famData = null; }
  renderFamilies();
}
function renderFamilies() {
  const box = $("fams"); if (!box) return;
  $("famPanel").hidden = !famData || !famData.families.length;
  if (!famData) return;
  const cur = profile ? profile.family : famData.current;
  const item = (key, emoji, label, sub, pct) => `<button type="button" class="fam${key === (cur || "") ? " on" : ""}" data-fam="${esc(key)}" aria-pressed="${key === (cur || "")}">
      <span class="fe">${emoji}</span><span class="fl">${esc(label)}</span><small>${sub}</small>${pct != null ? `<span class="fb"><i style="width:${pct}%"></i></span>` : ""}</button>`;
  box.innerHTML = item("", "🔀", "Mezcla", "las más comunes", null) + famData.families.map(f =>
    item(f.key, f.emoji, f.label, `${f.learned} de ${f.total}${f.mastered ? " · ⭐" + f.mastered : ""}`, f.total ? Math.round(f.learned / f.total * 100) : 0)).join("");
  box.querySelectorAll("[data-fam]").forEach(b => b.onclick = async () => {
    const family = b.dataset.fam || null;
    try {
      profile = await api("/settings", { method: "PUT", body: { family } });
      const f = famData.families.find(x => x.key === family);
      toast(f ? `${f.emoji} Tus palabras nuevas serán de: ${f.label}` : "🔀 Palabras nuevas por frecuencia");
      renderFamilies(); refresh();
    } catch (e) { alertSide(e.message); }
  });
}
