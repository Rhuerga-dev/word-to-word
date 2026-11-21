/* Mini-taller de la palabra que fallas (como en la app, core/utils/word_drill.dart): en «errores para repasar».
   Tras el 1.er intento fallido, si una palabra salió muy mal (nota Azure < 60) Y no se entendió, se practica sola
   (2 intentos, nota ≥ 70), luego en su trozo de frase, y se vuelve a la frase. Solo la peor, una vez por error.
   Necesita Azure (cfg.pronunciation). Interruptor en Ajustes → «Practicar la palabra que fallo».
   API: POST /pronunciation/tips {text, audio} (las palabras flojas) y POST /pronunciation/assess {text, phoneme?, audio}. */
"use strict";
const WD = { MAX: 60, PASS: 70, TRIES: 2 };

function wdOn() { try { return localStorage.getItem("wtw_word_drill") !== "0"; } catch (e) { return true; } }
function wdSetOn(on) { try { localStorage.setItem("wtw_word_drill", on ? "1" : "0"); } catch (e) {} }

const wdTokens = t => String(t || "").replace(/’/g, "'").replace(/[^A-Za-z0-9'\s]/g, " ").split(/\s+/).filter(Boolean);
const wdKey = w => String(w || "").toLowerCase().replace(/'/g, "");

/** El trozo con la palabra: ella y la siguiente (o la anterior si es la última); las muy cortas se juntan con otra. */
function wdChunk(sentence, word) {
  const ws = wdTokens(sentence), i = ws.findIndex(t => wdKey(t) === wdKey(word));
  if (i < 0 || ws.length < 2) return word;
  let from = i, to = i;
  if (i + 1 < ws.length) { to = i + 1; if (ws[to].length <= 3 && to + 1 < ws.length) to++; }
  else { from = i - 1; if (ws[from].length <= 3 && from > 0) from--; }
  const chunk = ws.slice(from, to + 1).join(" ");
  return /[0-9]/.test(chunk) ? word : chunk;   // el evaluador solo acepta letras
}

/** Elige UNA palabra (la peor), solo si de verdad salió mal: nota < 60 y además no se entendió (o faltó).
    [weak] = palabras de /pronunciation/tips; [tokens] = lo que comparó el servidor ([{w, ok}]). */
function wdPick(weak, sentence, tokens) {
  const ws = wdTokens(sentence);
  if (ws.length < 2) return null;
  const missed = new Set((tokens || []).filter(t => !t.ok).map(t => wdKey(t.w)));
  const cands = (weak || []).filter(w => {
    const k = wdKey(w.word);
    if (!k || /[0-9]/.test(k) || !ws.some(t => wdKey(t) === k)) return false;
    if ((w.accuracy ?? 0) >= WD.MAX) return false;
    return missed.has(k) || w.error === "Omission";
  }).sort((a, b) => (a.accuracy ?? 0) - (b.accuracy ?? 0));
  if (!cands.length) return null;
  const w = cands[0], word = ws.find(t => wdKey(t) === wdKey(w.word));
  return { word, chunk: wdChunk(sentence, word), sentence, phonemes: w.phonemes || [], stage: "word", tries: 0, score: null, msg: "", busy: false };
}

/** Las palabras flojas de lo que dijiste (se pide A LA VEZ que la nota). Si falla, ninguna: nunca se atasca. */
async function wdTips(text, wav) {
  try {
    const fd = new FormData(); fd.append("text", text); fd.append("audio", wav, "voz.wav");
    const r = await api("/pronunciation/tips", { method: "POST", body: fd });
    return r && r.words || [];
  } catch (e) { return []; }
}

/** Nota (0–100) de decir [text]; con [phoneme] mide ese sonido. */
async function wdAssess(text, phoneme, wav) {
  const fd = new FormData(); fd.append("text", text); if (phoneme) fd.append("phoneme", phoneme); fd.append("audio", wav, "voz.wav");
  const r = await api("/pronunciation/assess", { method: "POST", body: fd });
  return r.target_score != null ? r.target_score : (r.score || 0);
}

const wdStep = d => d.stage === "word" ? [d.word, d.phonemes[0] || null] : [d.chunk, null];
function wdAdvance(d) {
  d.tries = 0; d.score = null;
  d.stage = d.stage === "word" && d.chunk !== d.word ? "chunk" : "done";
}

/** La caja del mini-taller (dentro de la pantalla del error). */
function wdHTML(d) {
  if (d.stage === "done") return `<div class="drill done"><h4>Practiquemos una palabra</h4>
    <p class="note">3. Ahora la frase completa</p><p class="big">${esc(d.sentence)}</p>
    <div class="row"><button type="button" class="primary" data-wd="back">Decir la frase completa</button></div></div>`;
  const [text] = wdStep(d);
  return `<div class="drill"><h4>Practiquemos una palabra</h4>
    <p class="note">${d.stage === "word" ? "1. La palabra sola" : "2. En su trozo de frase"}</p>
    <p class="big">${esc(text)} <button type="button" class="round" data-wd="listen" aria-label="Escuchar">${ICON_SPK}</button></p>
    ${d.stage === "word" && typeof tipsHtml === "function" ? tipsHtml(d.word, d.phonemes) : ""}
    ${d.score != null ? `<p class="${d.score >= WD.PASS ? "banner ok" : "warnbox"}">${d.score >= WD.PASS ? `✓ ${d.score}/100` : `${d.score}/100 — escucha y otra vez`}</p>` : ""}
    ${d.msg ? `<p class="note">${esc(d.msg)}</p>` : ""}
    ${d.busy === "rec" ? `<p class="sp-status"><span class="hf-dot listen"></span>Te escucho… toca al terminar</p>` : ""}
    ${d.busy === "check" ? `<div class="w2w-wait" role="status"><span class="w2w-bars" aria-hidden="true"><i></i><i></i><i></i><i></i><i></i></span><p>Evaluando tu pronunciación…</p></div>` : ""}
    <div class="row">
      <button type="button" class="primary" data-wd="say"${d.busy === "check" ? " disabled" : ""}>🎙️ ${d.busy === "rec" ? "Ya terminé" : "Dilo tú"}</button>
      <button type="button" data-wd="skip"${d.busy ? " disabled" : ""}>Saltar</button></div></div>`;
}

/** Un intento con el dedo. [render] vuelve a dibujar la pantalla. */
async function wdAttempt(d, render) {
  if (d.busy === "rec") { if (typeof stopRecording === "function" && stopRecording) stopRecording(); return; }
  if (d.busy) return;
  const [text, phoneme] = wdStep(d);
  d.busy = "rec"; d.msg = ""; render();
  try {
    const wav = await recordWav(6000, null, 1.0);
    if (!wav.heard) { d.busy = false; d.msg = "No te oí. Habla un poco más cerca."; render(); return; }
    d.busy = "check"; render();
    d.score = await wdAssess(text, phoneme, wav);
    if (d.score >= WD.PASS) { d.msg = "¡Bien!"; wdAdvance(d); }
    else if (++d.tries >= WD.TRIES) { d.msg = "Sigue, la repasamos otro día."; wdAdvance(d); }
  } catch (e) { d.msg = e.message || "No se pudo evaluar."; }
  d.busy = false; render();
}

/** El mismo mini-taller por voz (manos libres). Si algo falla, se vuelve a la frase sin más. */
async function wdHandsFree(d, alive) {
  const es = typeof spStep === "function" && spStep() <= 2;
  await (es ? spSayEs("Vamos a practicar una palabra.") : spSay("Let's practice one word."));
  if (!alive()) return;
  await new Promise(r => { say(d.word, true); setTimeout(r, 1600); });
  const steps = [[d.word, d.phonemes[0] || null]]; if (d.chunk !== d.word) steps.push([d.chunk, null]);
  for (const [text, phoneme] of steps) {
    for (let i = 0; i < WD.TRIES; i++) {
      if (!alive()) return;
      await spSay(i === 0 ? `Say: ${text}.` : `Again: ${text}.`);
      const wav = await recordWav(6000, null, 1.0);
      if (!alive()) return;
      if (!wav.heard) continue;
      let score;
      try { score = await wdAssess(text, phoneme, wav); } catch (e) { return; }
      if (score >= WD.PASS) { await spSay("Good!"); break; }
      if (i + 1 < WD.TRIES) { await spSay("Listen."); await new Promise(r => { say(text, true); setTimeout(r, 1800); }); }
    }
  }
  if (alive()) await spSay("Now the whole sentence.");
}

// Ajustes → «Practicar la palabra que fallo».
(function () {
  const el = document.getElementById("wordDrillOn"); if (!el) return;
  el.checked = wdOn();
  el.onchange = e => wdSetOn(e.target.checked);
})();
