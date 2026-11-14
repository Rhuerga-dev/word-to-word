// Word to Word · Modo manos libres (antes en app.js; usa sus funciones globales: $, api, say…).

// ===== Modo manos libres =====
// La app habla, escucha y avanza sola. Comandos de voz: "pausa", "repite", "siguiente", "no sé".
const hf = { on: false, wake: null, sounds: {}, tipsSaid: new Set(), mode: (() => { try { return localStorage.getItem("wtw_hf_mode") || "words"; } catch (e) { return "words"; } })() };
let esVoice = null;
function pickEsVoice() { try { const vs = speechSynthesis.getVoices(); esVoice = vs.find(v => /^es[-_](US|MX|419)/i.test(v.lang)) || vs.find(v => /^es/i.test(v.lang)) || null; } catch (e) {} }
if ("speechSynthesis" in window) { pickEsVoice(); speechSynthesis.addEventListener && speechSynthesis.addEventListener("voiceschanged", pickEsVoice); }
function hfStatus(text, mode) {
  const html = `<span class="hf-dot ${mode || ""}"></span>${esc(text)}`;
  $("hfState").innerHTML = html;
  const f = $("focusStep"); if (f) f.innerHTML = html; // también en la tarjeta de enfoque
}
async function speakP(text, lang, rate) {
  if (!hf.on || !text) return;
  [text, lang] = uiSpeech(text, lang);
  if (useTts()) {
    hfStatus(text, "speak");
    try { return await playTts(text, lang.startsWith("es") ? "es" : "en", !!rate && rate < (lang.startsWith("es") ? 0.95 : 0.8)); }
    catch (e) { /* si falla la voz natural, sigue con la del navegador */ }
  }
  return speakBrowser(text, lang, rate);
}
function speakBrowser(text, lang, rate) {
  return new Promise(resolve => {
    if (!hf.on || !("speechSynthesis" in window) || !text) return resolve();
    // En el iPhone, cancel() justo antes de speak() hace que se pierda la frase: solo si hay algo sonando.
    if (speechSynthesis.speaking || speechSynthesis.pending) speechSynthesis.cancel();
    try { speechSynthesis.resume(); } catch (e) {}
    const u = new SpeechSynthesisUtterance(text);
    u.lang = lang; u.rate = rate || (lang.startsWith("es") ? 1 : 0.9);
    if (lang.startsWith("es") && esVoice) u.voice = esVoice; else if (lang.startsWith("en") && voice) u.voice = voice;
    let done = false; const fin = () => { if (!done) { done = true; resolve(); } };
    u.onend = fin; u.onerror = fin;
    setTimeout(fin, 2500 + text.length * 120); // por si el navegador no avisa del final
    hfStatus(text, "speak");
    speechSynthesis.speak(u);
  });
}
const en = (t, slow) => speakP(t, "en-US", slow ? 0.65 : 0.9);
const es = (t, slow) => speakP(t, "es-ES", slow ? 0.8 : 1);
// Escalera de español: desde el escalón 2 el modo manos libres habla en inglés.
const hfSay = (tEs, tEn, slow) => spStep() >= 2 ? en(tEn, slow) : es(tEs, slow);
/** Lo que significa la palabra, en voz: traducción (escalón 1) o la definición en inglés. */
async function hfMeaning(c, prefixEs = "") {
  if (!c.hide_translation) return es(prefixEs + "Significa " + c.translation + ".");
  if (c.definition) return en(c.definition);
}
let hfRec = null;
/** ¿Puede entender lo que dices? Chrome lo hace en el navegador; el iPhone, con el servidor (Azure). */
const hfHears = () => !!SR || !!cfg.pronunciation;
/**
 * Escucha y devuelve lo entendido (varias alternativas). Si no oyó nada, el resultado lleva .silent.
 * Con [count] (por defecto) dos silencios seguidos ponen el manos libres en pausa: nunca se avanza ni se
 * califica una ficha sin tu respuesta.
 */
async function listenP(lang, ms, count = true) {
  if (!hf.on) return [];
  const got = SR ? await browserHear(lang, ms) : cfg.pronunciation ? await serverHear(lang, ms) : [];
  if (!hf.on) return got;
  if (!got.length) { got.silent = true; if (count) await hfHeardNothing(); }
  else hf.silent = 0;
  return got;
}
function browserHear(lang, ms) {
  return new Promise(resolve => {
    const r = new SR(); hfRec = r; r.lang = lang; r.maxAlternatives = 4; r.interimResults = false; r.continuous = false;
    let got = []; const t = setTimeout(() => { try { r.stop(); } catch (e) {} }, ms || 7000);
    r.onresult = e => { got = [...e.results[0]].map(a => a.transcript); };
    r.onerror = () => {};
    r.onend = () => { clearTimeout(t); hfRec = null; resolve(got); };
    hfStatus(lang.startsWith("es") ? "Te escucho… (en español)" : "Te escucho… (en inglés)", "listen");
    try { r.start(); } catch (e) { clearTimeout(t); resolve([]); }
  });
}
// iPhone: Safari no reconoce voz, así que se graba y el servidor la pasa a texto.
async function serverHear(lang, ms) {
  hfStatus(lang.startsWith("es") ? "Te escucho… (en español)" : "Te escucho… (en inglés)", "listen");
  let wav;
  try { wav = await recordWav(ms || 7000, null, 1.2); } catch (e) { return []; }
  if (!hf.on || !wav.heard) return [];
  hfStatus("Entendiendo lo que dijiste…");
  const fd = new FormData(); fd.append("audio", wav, "voz.wav"); fd.append("lang", lang.startsWith("es") ? "es" : "en");
  try { const r = await api("/speech/transcribe", { method: "POST", body: fd }); return r.text ? [r.text] : []; }
  catch (e) { return []; }
}
/** No te oyó: a la segunda vez seguida lo dice y se pausa en la misma ficha. Devuelve true si se pausó. */
async function hfHeardNothing() {
  hf.silent = (hf.silent || 0) + 1;
  if (hf.silent < 2) return false;
  hf.silent = 0; hf.silencePaused = true;
  await hfSay("No te oigo. Lo dejo en pausa; actívalo cuando quieras seguir.", "I can't hear you. I'll pause here. Turn it back on when you're ready.");
  stopHF();
  return true;
}
/** Pregunta y espera respuesta: si no te oye, te lo vuelve a pedir una vez (y luego se pausa). null = en pausa. */
async function hfAsk(lang, ms, askAgain) {
  for (let i = 0; i < 2; i++) {
    const alts = await listenP(lang, ms);
    if (!hf.on) return null;
    if (!alts.silent) return alts;
    if (askAgain) await askAgain();
  }
  return null;
}
function noAccents(t) { return String(t || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[^a-z0-9ñ\s]/g, " ").replace(/\s+/g, " ").trim(); }
function command(alts) {
  const t = noAccents(alts.join(" "));
  if (/\b(pausa|pausar|detente|deten|stop|para ya|terminar)\b/.test(t)) return "pause";
  if (/\b(repite|repetir|otra vez|again|repeat)\b/.test(t)) return "repeat";
  if (/\b(siguiente|salta|saltar|next|skip)\b/.test(t)) return "skip";
  if (/\b(no se|no lo se|ni idea|no recuerdo|no me acuerdo)\b/.test(t)) return "dontknow";
  return null;
}
function meaningMatches(translation, alts) {
  const heard = alts.map(noAccents);
  const options = String(translation || "").replace(/\([^)]*\)/g, " ").split(/[,;/]| o /).map(noAccents).filter(Boolean);
  return options.some(o => heard.some(h => (" " + h + " ").includes(" " + o + " ") || o.split(" ").some(w => w.length >= 4 && (" " + h + " ").includes(" " + w + " "))));
}
function wordHeard(word, alts) { const w = norm(word).join(" "); return alts.some(a => (" " + norm(a).join(" ") + " ").includes(" " + w + " ")); }

// ----- Corrección de pronunciación en manos libres -----
// Con Azure: graba tu voz y la califica sonido por sonido (funciona también en el iPhone).
// Sin Azure: usa el reconocimiento del navegador y da pistas por la ortografía.
const HF_WORD_PASS = 80;
async function hfAssess(c, target, text, ms) {
  const ref = target === "sentence" ? plain(c.example) : (text || c.word);
  if (cfg.pronunciation) {
    hfStatus("Grabando… habla ahora", "listen");
    const wav = await recordWav(ms || (target === "sentence" ? 8000 : 3000), null, target === "sentence" ? 1.0 : 0.6);
    hfStatus("Evaluando tu pronunciación…");
    const fd = new FormData(); fd.append("target", target); fd.append("audio", wav, "voz.wav");
    if (target === "text") fd.append("text", ref);
    let r;
    try { r = await api(`/words/${c.id}/pronunciation`, { method: "POST", body: fd }); }
    catch (e) { if (/límite/i.test(e.message)) throw e; hfStatus(e.message); return { pct: 0, weak: [], silent: true }; }
    const out = $("heard"); if (out) showAzure(r, out);
    const a = r.assessment;
    if (!a || a.status !== "Success") { await hfHeardNothing(); return { pct: 0, weak: [], silent: true }; }
    hf.silent = 0;
    const weak = a.words.filter(w => w.error !== "Insertion" && (w.error !== "None" || w.accuracy < HF_WORD_PASS))
      .map(w => ({ word: w.word, bad: w.phonemes.filter(p => p.accuracy < 60).map(p => p.phoneme).filter(Boolean) }));
    return { pct: r.score, weak };
  }
  const alts = await listenP("en-US", ms || (target === "sentence" ? 9000 : 5000));
  if (!alts.length) return { pct: 0, weak: [], silent: true, alts };
  let best = null; alts.forEach(a => { const r = compare(ref, a); if (!best || r.pct > best.pct) best = r; });
  const out = $("heard");
  if (out) verdict(out, best.pct, '<span class="note">Entendí: “' + esc(alts[0]) + '”</span>', best.toks.map(z => `<span class="tok ${z.ok ? "ok" : "miss"}">${esc(z.x)}</span>`).join(""));
  if (target !== "text") api(`/words/${c.id}/pronunciation`, { method: "POST", body: { target, score: best.pct } }).catch(() => {});
  const weak = [...new Set(best.toks.filter(z => !z.ok).map(z => z.x))].map(w => ({ word: w, bad: [] }));
  return { pct: best.pct, weak, alts };
}
// Elige el consejo más útil para una palabra (sonido que falló o, sin Azure, por cómo se escribe).
function tipKey(word, bad) {
  for (const p of bad || []) { const k = PRON_TIPS[p] ? p : PRON_TIPS[String(p).replace("ː", "")] ? String(p).replace("ː", "") : null; if (k) return k; }
  return spellingTips(word)[0] || null;
}
const firstSentence = t => { const i = String(t).indexOf(". "); return i > -1 ? t.slice(0, i + 1) : t; };
const spokenPair = pair => String(pair || "").replace(/\s*\/\s*/g, ", ").replace(/\s*·\s*/g, ". ");
// Dice el consejo en voz alta, lo muestra en pantalla y pone las palabras de contraste.
async function hfTip(word, bad) {
  const k = tipKey(word, bad);
  const box = $("drill");
  if (box) { box.className = "drill"; box.innerHTML = `<h4>Practica: <b>${esc(word)}</b></h4>${tipsHtml(word, bad)}`; }
  if (!k) { await es("Escúchala lenta y repítela separando las sílabas."); return; }
  const t = PRON_TIPS[k];
  hf.sounds[k] = (hf.sounds[k] || 0) + 1;
  if (hf.tipsSaid.has(k)) {
    await es("Recuerda: " + firstSentence(t.how));
  } else {
    hf.tipsSaid.add(k);
    await es("Consejo. " + t.how);
    if (t.pair) { await es("Escucha la diferencia."); await en(spokenPair(t.pair), true); }
  }
}
async function hfRepeatSentence(c) {
  for (let attempt = 0; attempt < 2 && hf.on; attempt++) {
    await es(attempt ? "Otra vez. Repite la frase completa." : "Repite la frase.");
    const r = await hfAssess(c, "sentence");
    if (!hf.on) return "pause";
    if (r.silent) { await es("No te oí. Habla un poco más cerca."); continue; }
    const cmd = r.alts && r.pct < 50 ? command(r.alts) : null; if (cmd) return cmd;
    if (r.pct >= 90) { await es(r.pct >= 97 ? pick(["¡Perfecto!", "¡Impecable!", "¡Como un nativo!"]) : pick(HF_PRAISE)); return null; }
    await es(r.pct >= 70 ? "Casi. Vamos a pulir " + (r.weak.length > 1 ? "unas palabras." : "una palabra.") : "Vamos por partes.");
    for (const w of r.weak.slice(0, 3)) {
      const res = await hfDrillWord(c, w.word, w.bad); if (res) return res;
    }
    if (hf.on) { await es("Ahora escucha la frase y repítela."); await en(plain(c.example), true); }
  }
  return null;
}
async function hfDrillWord(c, w, bad) {
  await hfTip(w, bad);
  for (let i = 0; i < 3 && hf.on; i++) {
    await en(w, true); if (i === 2) await en(w);
    const r = await hfAssess(c, w.toLowerCase() === String(c.word).toLowerCase() ? "word" : "text", w, 3500);
    if (!hf.on) return "pause";
    const ok = cfg.pronunciation ? (!r.silent && r.pct >= HF_WORD_PASS) : (r.alts && wordHeard(w, r.alts));
    if (ok) { await es(i ? pick(["¡Ahora sí!", "¡Esa es!", "¡Mucho mejor!"]) : pick(HF_PRAISE)); return null; }
    const cmd = r.alts ? command(r.alts) : null; if (cmd === "pause" || cmd === "skip") return cmd;
    if (r.silent) { await es("No te oí."); continue; }
    // Si sigue fallando, otro consejo con el sonido que falló esta vez.
    if (i === 0 && r.weak[0] && r.weak[0].bad.length && tipKey(w, r.weak[0].bad) !== tipKey(w, bad)) await hfTip(w, r.weak[0].bad);
    else if (i < 2) await es(i === 0 ? "Otra vez, más despacio." : "Una más. Exagera la boca.");
  }
  await es("Seguimos. La practicaremos más tarde.");
  return null;
}
// Al terminar: el sonido que más costó hoy.
async function hfSummary() {
  const top = Object.entries(hf.sounds).sort((a, b) => b[1] - a[1])[0];
  if (!top) return;
  const t = PRON_TIPS[top[0]];
  await es("Lo que más te costó hoy fue este sonido. " + firstSentence(t.how) + " Practícalo unos minutos con estas palabras.");
  await en(spokenPair(t.pair), true);
}
// ----- AID y progresión palabra → frase en manos libres -----
// Primero se practica la palabra sola. Cuando ya la acertaste en varios repasos
// (nivel 2 o más: la recordaste a 3 y a 7 días), se pasa a repetir la frase completa.
const HF_SENTENCE_FROM_LEVEL = 2;
const hfPhase = c => (c.mode !== "new" && (c.level || 0) >= HF_SENTENCE_FROM_LEVEL) ? "sentence" : "word";
// La escena AID de la palabra: la tuya, o una que propone la IA (se guarda para que la puedas editar).
const AID_MAX = 110; // escenas más largas se cambian por una corta para memorizarla de una vez
async function hfGetAid(c) {
  if (c.aid && (c.aid.length <= AID_MAX || !cfg.ai)) return c.aid;
  if (!cfg.ai) return null;
  try {
    hfStatus("Pensando una escena para recordarla…");
    const r = await api(`/words/${c.id}/aid/suggest`, { method: "POST" });
    const scene = (r.suggestions || [])[0];
    if (!scene) return null;
    c.aid = scene;
    api(`/words/${c.id}/aid`, { method: "PUT", body: { aid: scene } }).catch(() => {});
    if (revealed) render();
    return scene;
  } catch (e) { return null; }
}
// La voz cuenta la escena despacio, deja un momento para imaginarla y te pide repetirla.
async function hfAid(c, intro, repeat = true) {
  if (spStep() >= 2) return false; // las escenas AID son en español: solo en el escalón 1
  const scene = await hfGetAid(c);
  if (!scene || !hf.on) return false;
  await es(intro || pick(["Para recordarla, imagina esto.", "Truco para memorizarla. Imagina:", "Visualiza esta escena."]));
  await es(scene.replace(/[“”"]/g, ""), true);
  await es(pick(["Imagínalo con detalle, con colores y ruido.", "Cierra los ojos un segundo y míralo.", "Entre más absurda, mejor se queda."]));
  await new Promise(r => setTimeout(r, 1500));
  if (repeat && hf.on) await hfRepeatAid(c, scene);
  return true;
}
// La "clave" de la escena: lo que va entre comillas (el sonido parecido en español).
function aidKey(scene) { const m = String(scene).match(/[“"']([^”"']{2,40})[”"']/); return m ? m[1].trim() : ""; }
// Tú cuentas la escena en voz alta: decirla con tus palabras es lo que la fija en la memoria.
async function hfRepeatAid(c, scene) {
  const key = aidKey(scene), meaning = String(c.translation || "").split(/[;,/]/)[0].trim();
  await es(pick(["Ahora cuéntamela tú, en voz alta y con tus palabras.", "Tu turno: repite la escena en voz alta.", "Repítela tú. Decirla en voz alta la fija en tu memoria."]));
  if (hfHears()) {
    const alts = await listenP("es-ES", 12000, false);
    if (!hf.on) return;
    if (!alts.length) { await es("No te oí, no pasa nada. Repítela en tu mente."); }
    else {
      const heard = noAccents(alts.join(" "));
      const hasKey = key && noAccents(key).split(" ").some(w => w.length >= 3 && heard.includes(w));
      const hasMeaning = meaningMatches(c.translation, alts);
      if (hasKey && hasMeaning) await es(pick(["¡Perfecto! Uniste el sonido con el significado.", "¡Excelente! Así no se te olvida."]));
      else if (hasKey) await es("Bien. Y recuerda que significa " + meaning + ".");
      else if (hasMeaning) await es(key ? "Bien. No olvides el sonido: " + key + "." : "¡Bien!");
      else await es("Casi. La clave es " + (key ? key + ", que suena como la palabra, " : "") + "y la escena trata de " + meaning + ".");
    }
  } else if (cfg.pronunciation) {
    // iPhone: no hay reconocimiento en español, pero se te da el tiempo y se espera a que termines de hablar.
    hfStatus("Cuéntala en voz alta…", "listen");
    try { await recordWav(12000, null, 1.6); } catch (e) {}
    if (!hf.on) return;
    await es(pick(["¡Bien! Decirla en voz alta ayuda a recordarla.", "¡Eso es! Ya la tienes más fija.", "Muy bien, así se queda."]));
  } else {
    await new Promise(r => setTimeout(r, 8000));
  }
  if (hf.on && key) { await es("Recuerda:"); await es(key, true); await en(c.word, true); }
}
// Dos botones grandes en la tarjeta: "La sabía" / "No la sabía" (8 s para responder).
function hfAskRecall() {
  return new Promise(resolve => {
    const box = $("drill"); if (!box) return resolve(null);
    box.className = "drill"; box.innerHTML = `<div class="row" style="justify-content:center;gap:12px">
      <button type="button" class="primary" id="recallYes" style="font-size:18px;padding:14px 22px">✅ La sabía</button>
      <button type="button" id="recallNo" style="font-size:18px;padding:14px 22px">❌ No la sabía</button></div>`;
    let done = false; const fin = v => { if (done) return; done = true; box.innerHTML = ""; resolve(v); };
    $("recallYes").onclick = () => fin(true); $("recallNo").onclick = () => fin(false);
    hfStatus("¿La recordabas? Toca sí o no", "listen");
    setTimeout(() => fin(null), 8000);
  });
}
const hfWordOk = (r, w) => cfg.pronunciation ? (!r.silent && r.pct >= HF_WORD_PASS) : !!(r.alts && wordHeard(w, r.alts));
// Practicar la palabra sola: dila, y si sale mal, consejo + repaso del sonido.
async function hfPracticeWord(c) {
  for (let attempt = 0; attempt < 2 && hf.on; attempt++) {
    await es(attempt ? "Otra vez, dila tú." : pick(["Ahora dila tú.", "Repítela.", "Tu turno, dila."]));
    const r = await hfAssess(c, "word", c.word, 3500);
    if (!hf.on) return "pause";
    const cmd = r.alts && !hfWordOk(r, c.word) ? command(r.alts) : null; if (cmd) return cmd;
    if (r.silent) { await es("No te oí. Habla un poco más cerca."); continue; }
    if (hfWordOk(r, c.word)) { await es(pick(HF_PRAISE)); return null; }
    return await hfDrillWord(c, c.word, (r.weak[0] || {}).bad);
  }
  return hf.on ? null : "pause";
}
// Según el avance de la palabra: palabra sola, o frase completa.
async function hfPractice(c) {
  if (hfPhase(c) === "word") return hfPracticeWord(c);
  await es(pick(["Ya la conoces bien. Ahora en una frase.", "Subimos de nivel: la frase completa.", "Ahora úsala en una frase."]));
  await en(plain(c.example), true);
  return hfRepeatSentence(c);
}
async function hfNew(c) {
  revealed = true; render();
  if (c.family && hf.lastFam !== c.category) { hf.lastFam = c.category; await es("Familia: " + c.family.label + "."); }
  await hfSay("Palabra nueva.", "New word."); await en(c.word); await hfMeaning(c);
  await hfAid(c);
  if (!hf.on) return;
  await en(c.word, true);
  const r = await hfPracticeWord(c);
  if (r === "pause" || !hf.on) return stopHF();
  if (r === "repeat") return; // vuelve a empezar la misma ficha
  if (r === "skip") { cards.push(cards.shift()); render(); return; }
  await api(`/words/${c.id}/learn`, { method: "POST" });
  cards.shift(); revealed = false; render();
}
async function hfReview(c) {
  revealed = false; render();
  if (!hfHears()) {
    // Sin reconocimiento de voz (ni navegador ni servidor): piensas la respuesta y dices con un toque si la sabías.
    await en(c.word); await hfSay("Piensa qué significa.", "Think about what it means."); await new Promise(r => setTimeout(r, 3000));
    revealed = true; render();
    await hfMeaning(c); await hfSay("¿La recordabas? Toca sí o no.", "Did you remember it? Tap yes or no.");
    // Sin reconocimiento en español no puedo saber si acertaste: tú lo dices con un toque.
    const knew = await hfAskRecall();
    if (!hf.on) return;
    // Sin respuesta no se califica: se pausa en esta ficha.
    if (knew === null) { hf.silencePaused = true; return stopHF(); }
    if (knew === false || (c.fails || 0) >= 1) await hfAid(c, knew === false ? "Para que no se te olvide, imagina esto." : "Recuerda tu escena.", knew === false);
    else if (knew) await es(pick(["¡Muy bien!", "¡Excelente!", "¡Eso es!"]));
    const r = await hfPractice(c);
    if (r === "pause") return stopHF();
    if (r === "skip") { cards.push(cards.shift()); render(); return; }
    if (!hf.on) return;
    // Sabías → avanza. No sabías → vuelve mañana.
    await api(`/words/${c.id}/review`, { method: "POST", body: { grade: knew ? "good" : "again" } });
    cards.shift(); revealed = false; render();
    return;
  }
  // Escalón 2+: se recuerda desde el inglés (la definición) y se contesta con la palabra en inglés.
  if (c.hide_translation && c.definition) return hfReviewEnglish(c);
  await en(c.word); await es("¿Qué significa?");
  let alts = await hfAsk("es-ES", 7000, () => es("Tómate tu tiempo. ¿Qué significa?"));
  if (!alts) return;
  let cmd = command(alts);
  if (cmd === "pause") return stopHF();
  if (cmd === "repeat") return;
  if (cmd === "skip") { cards.push(cards.shift()); render(); return; }
  let ok = cmd !== "dontknow" && meaningMatches(c.translation, alts), hinted = false;
  // Si no la recuerdas, la escena AID sirve de pista y tienes otra oportunidad.
  if (!ok && c.aid && c.aid.length > AID_MAX) await hfGetAid(c); // escena larga → una corta
  if (!ok && c.aid && hf.on) {
    await es((alts.length && cmd !== "dontknow" ? "No exactamente. " : "") + "Te doy una pista con tu escena.");
    await es(c.aid.replace(/[“”"]/g, ""), true);
    await es("¿Ahora sí? ¿Qué significa?");
    alts = await hfAsk("es-ES", 7000, () => es("¿Qué significa?"));
    if (!alts) return;
    cmd = command(alts);
    if (cmd === "pause") return stopHF();
    ok = cmd !== "dontknow" && meaningMatches(c.translation, alts); hinted = true;
  }
  revealed = true; render();
  if (ok) { await es((hinted ? "¡Eso es! La escena funcionó. " : pick(["¡Correcto! ", "¡Exacto! ", "¡Muy bien! "])) + "Significa " + c.translation + "."); }
  else {
    await es((alts.length && cmd !== "dontknow" ? "No exactamente. " : "") + "Significa " + c.translation + ".");
    if (!hinted) await hfAid(c, "Para que no se te olvide, imagina esto.");
    else if (c.aid) await hfRepeatAid(c, c.aid);
  }
  await en(c.word);
  const r = await hfPractice(c); if (r === "pause" || !hf.on) return stopHF();
  await api(`/words/${c.id}/review`, { method: "POST", body: { grade: ok ? (hinted ? "hard" : "good") : "again" } });
  cards.shift(); revealed = false; render();
}
// Repaso sin español: la definición en inglés y dices la palabra.
async function hfReviewEnglish(c) {
  await en(c.definition); await en("What's the word?");
  const alts = await hfAsk("en-US", 6000, () => en("Take your time. What's the word?"));
  if (!alts) return;
  const cmd = command(alts);
  if (cmd === "pause") return stopHF();
  if (cmd === "repeat") return;
  if (cmd === "skip") { cards.push(cards.shift()); render(); return; }
  const w = c.word.toLowerCase(), ok = cmd !== "dontknow" && alts.some(a => String(a).toLowerCase().includes(w));
  revealed = true; render();
  await en(ok ? pick(["Correct!", "Exactly!", "Well done!"]) : "The word is");
  await en(c.word);
  const r = await hfPractice(c); if (r === "pause" || !hf.on) return stopHF();
  await api(`/words/${c.id}/review`, { method: "POST", body: { grade: ok ? "good" : "again" } });
  cards.shift(); revealed = false; render();
}
// ----- Modo frases: te digo la frase, la repites, si está bien seguimos -----
const SHADOW_PASS = 80;
async function hfShadow(c) {
  revealed = true; render();
  const sentence = plain(c.example);
  let passed = false;
  for (let attempt = 0; attempt < 3 && hf.on; attempt++) {
    if (attempt === 0) {
      await en(sentence, true);
      if (c.example_es && !c.hide_translation) await es(c.example_es);
      await hfSay("Repite.", "Repeat.");
    } else {
      await es(attempt === 1 ? "Otra vez. Escucha." : "Una más, despacio.");
      await en(sentence, true);
    }
    const r = await hfAssess(c, "sentence");
    if (!hf.on) return;
    const cmd = r.alts && r.pct < 50 ? command(r.alts) : null;
    if (cmd === "pause") return stopHF();
    if (cmd === "skip") break;
    if (cmd === "repeat") { attempt--; continue; }
    if (r.silent) { await es("No te oí."); continue; }
    if (r.pct >= SHADOW_PASS) { passed = true; await es(pick(HF_PRAISE)); break; }
    // Falló: practica la palabra que más costó y vuelve a intentar la frase.
    const w = r.weak[0];
    if (w && attempt < 2) { const res = await hfDrillWord(c, w.word, w.bad); if (res === "pause") return stopHF(); }
  }
  if (!hf.on) return;
  if (!passed) await es("La seguimos practicando otro día.");
  // Nueva: queda aprendida. Repaso: bien si la dijiste bien, si no vuelve pronto.
  if (c.mode === "new") await api(`/words/${c.id}/learn`, { method: "POST" });
  else await api(`/words/${c.id}/review`, { method: "POST", body: { grade: passed ? "good" : "hard" } });
  cards.shift(); revealed = false; render();
}
async function hfLoop() {
  try {
    while (hf.on) {
      const c = cards[0];
      if (!c) { await es(pick(["¡Terminaste por hoy! Excelente trabajo.", "¡Listo por hoy! Lo hiciste muy bien.", "¡Sesión completa! Estoy orgulloso de ti."])); await hfSummary(); stopHF(); render(); break; }
      if (hf.mode === "sentences") await hfShadow(c);
      else c.mode === "new" ? await hfNew(c) : await hfReview(c);
      if (hf.on) { try { stats = await api("/stats"); renderSide(); } catch (e) {} }
    }
  } catch (e) { hfStatus(e.message || "Algo falló. Vuelve a activar el modo manos libres."); stopHF(true); }
}
async function startHF() {
  if (!hfHears()) { $("hfOn").checked = false; hfStatus("Necesita reconocimiento de voz: usa Chrome en la Mac o en Android, o activa Azure en el servidor."); return; }
  hf.on = true; hf.sounds = {}; hf.tipsSaid = new Set(); hf.silent = 0; hf.silencePaused = false; showTab(false);
  document.body.classList.add("focus"); render(); try { window.scrollTo({ top: 0, behavior: "smooth" }); } catch (e) {}
  // La primera frase sale ya, todavía dentro del toque (el iPhone lo exige); la pantalla encendida se pide sin esperar.
  const intro = es((hf.mode === "sentences" ? "Modo frases. Te digo una frase, la repites, y si está bien seguimos. " : "Modo manos libres. ") + (hfHears() ? "Di pausa cuando quieras parar." : "Para parar, toca el interruptor."));
  try { if (navigator.wakeLock) navigator.wakeLock.request("screen").then(w => { hf.wake = w; }).catch(() => {}); } catch (e) {}
  await intro;
  hfLoop();
}
function stopHF(keepMsg) {
  hf.on = false; $("hfOn").checked = false;
  try { speechSynthesis.cancel(); } catch (e) {}
  try { ttsAudio.pause(); } catch (e) {}
  try { hfRec && hfRec.abort(); } catch (e) {}
  try { hf.wake && hf.wake.release(); } catch (e) {} hf.wake = null;
  if (!keepMsg) hfStatus(hf.silencePaused ? "En pausa porque no te oí. Actívalo cuando quieras seguir: sigues en esta ficha." : "En pausa. Actívalo de nuevo para seguir.");
  document.body.classList.remove("focus");
  render();
}
// El iPhone solo deja hablar y grabar si empieza dentro del toque del usuario:
// se "desbloquean" la voz y el audio aquí mismo, antes de cualquier espera.
function unlockAudio() {
  unlockTts();
  try {
    // La voz se desbloquea con la primera frase, que startHF() dice todavía dentro del toque.
    if ("speechSynthesis" in window) { pickVoice(); pickEsVoice(); }
  } catch (e) {}
  try {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (AC && (!hfAudioCtx || hfAudioCtx.state === "closed")) hfAudioCtx = new AC();
    if (hfAudioCtx && hfAudioCtx.state === "suspended") hfAudioCtx.resume();
  } catch (e) {}
}
$("hfMode").value = hf.mode;
$("hfMode").onchange = e => { hf.mode = e.target.value; try { localStorage.setItem("wtw_hf_mode", hf.mode); } catch (er) {} if (hf.on) render(); };
$("hfOn").onchange = e => { if (e.target.checked) { unlockAudio(); startHF(); } else stopHF(); };
