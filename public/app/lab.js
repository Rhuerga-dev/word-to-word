// Word to Word · Taller de pronunciación (antes en app.js; usa sus funciones globales: $, api, say…).

// ===================== Taller de pronunciación =====================
// Técnicas: 1) cómo se articula (colocación), 2) entrenar el oído con pares mínimos,
// 3) imitar despacio y luego a velocidad normal (shadowing), 4) producir el contraste,
// 5) usarlo en una frase, y 6) repetición espaciada: el taller vuelve mañana, en 3, 7 y 14 días.
// Cada ejercicio se evalúa sonido por sonido hasta que sale.
const LAB_PASS = 80, LAB_SENT_PASS = 75, LAB_TRIES = 5;
const DRILLS = {
  "θ": { words: ["think", "three", "thank", "bath", "mouth"], pairs: [["think", "sink"], ["three", "tree"], ["thank", "tank"], ["mouth", "mouse"]], sentence: "I think three thin men are thirsty." },
  "ð": { words: ["they", "this", "mother", "brother", "weather"], pairs: [["they", "day"], ["then", "den"], ["those", "doze"]], sentence: "This is my mother and that is my brother." },
  "v": { words: ["very", "voice", "love", "have", "seven"], pairs: [["very", "berry"], ["vote", "boat"], ["vest", "best"], ["van", "ban"]], sentence: "I have a very valuable van." },
  "b": { words: ["boat", "best", "baby", "job", "big"], pairs: [["ban", "van"], ["best", "vest"], ["boat", "vote"]], sentence: "Bob brought a big black bag." },
  "ʃ": { words: ["she", "ship", "shop", "wash", "nation"], pairs: [["she", "see"], ["ship", "sip"], ["shoe", "sue"]], sentence: "She sells shoes in a shop." },
  "tʃ": { words: ["check", "chair", "much", "watch", "teacher"], pairs: [["chip", "ship"], ["watch", "wash"], ["cheap", "sheep"]], sentence: "Check the chicken in the kitchen." },
  "dʒ": { words: ["job", "just", "age", "bridge", "enjoy"], pairs: [["jet", "yet"], ["jam", "yam"], ["joke", "yolk"]], sentence: "Jack just enjoyed his new job." },
  "ʒ": { words: ["usual", "vision", "measure", "television", "pleasure"], pairs: [], sentence: "It is usually a pleasure to watch television." },
  "z": { words: ["zoo", "zero", "is", "was", "easy"], pairs: [["zoo", "sue"], ["prize", "price"], ["eyes", "ice"]], sentence: "His dog is lazy and easy." },
  "h": { words: ["house", "hello", "happy", "behind", "who"], pairs: [["hat", "at"], ["hold", "old"], ["hair", "air"]], sentence: "Hello, how is your happy home?" },
  "ɹ": { words: ["red", "right", "road", "very", "sorry"], pairs: [["right", "light"], ["road", "load"], ["rice", "lice"]], sentence: "The red road runs right by the river." },
  "ŋ": { words: ["thing", "sing", "long", "morning", "working"], pairs: [["thing", "thin"], ["sing", "sin"], ["rang", "ran"]], sentence: "I am singing and dancing in the morning." },
  "j": { words: ["yes", "yet", "year", "you", "young"], pairs: [["yes", "Jess"], ["yet", "jet"], ["year", "jeer"]], sentence: "Yes, you can use it this year." },
  "w": { words: ["work", "would", "water", "west", "away"], pairs: [["would", "good"], ["west", "guest"], ["wood", "good"]], sentence: "We would walk to work in the west." },
  "ɪ": { words: ["ship", "sit", "live", "big", "fish"], pairs: [["ship", "sheep"], ["sit", "seat"], ["live", "leave"], ["fill", "feel"]], sentence: "This big fish is in it." },
  "i": { words: ["sheep", "seat", "leave", "eat", "green"], pairs: [["sheep", "ship"], ["seat", "sit"], ["leave", "live"]], sentence: "We eat green peas each week." },
  "ɛ": { words: ["bed", "men", "get", "red", "said"], pairs: [["bed", "bad"], ["men", "man"], ["pen", "pain"]], sentence: "Ten men get a red pen." },
  "æ": { words: ["cat", "bad", "man", "apple", "happy"], pairs: [["cat", "cut"], ["bad", "bed"], ["man", "men"], ["hat", "hot"]], sentence: "The black cat sat on a hat." },
  "ʌ": { words: ["cup", "but", "love", "money", "sun"], pairs: [["cup", "cap"], ["luck", "lock"], ["but", "bat"]], sentence: "My brother loves the summer sun." },
  "ə": { words: ["about", "banana", "problem", "sofa", "again"], pairs: [], sentence: "Ask about the problem again." },
  "ɑ": { words: ["hot", "stop", "father", "car", "job"], pairs: [["hot", "hat"], ["lock", "luck"], ["cop", "cup"]], sentence: "Stop the hot car, father." },
  "ɔ": { words: ["law", "call", "talk", "walk", "saw"], pairs: [["law", "low"], ["caught", "coat"], ["walk", "woke"]], sentence: "I saw him walk and talk in the hall." },
  "ʊ": { words: ["book", "good", "look", "full", "put"], pairs: [["full", "fool"], ["look", "Luke"], ["pull", "pool"]], sentence: "Look at this good book." },
  "u": { words: ["food", "blue", "school", "move", "two"], pairs: [["fool", "full"], ["pool", "pull"], ["Luke", "look"]], sentence: "Two blue shoes at school." },
  "oʊ": { words: ["go", "phone", "know", "home", "slow"], pairs: [["coat", "caught"], ["low", "law"], ["boat", "bought"]], sentence: "Go home slowly and don't phone." },
  "eɪ": { words: ["day", "late", "rate", "make", "name"], pairs: [["late", "let"], ["sale", "sell"], ["pain", "pen"]], sentence: "Stay late and play all day." },
  "ɜ": { words: ["work", "bird", "first", "learn", "girl"], pairs: [["work", "walk"], ["bird", "bud"], ["heard", "hard"]], sentence: "The first bird learned a word." },
  "l": { words: ["call", "feel", "milk", "people", "little"], pairs: [["light", "right"], ["load", "road"]], sentence: "People feel well in the cool hall." },
  "t": { words: ["bet", "cat", "sit", "eat", "right"], pairs: [["bet", "bed"], ["cart", "card"], ["seat", "seed"]], sentence: "Put the hat on that cat." },
  "d": { words: ["bed", "need", "food", "good", "said"], pairs: [["bed", "bet"], ["need", "neat"], ["card", "cart"]], sentence: "I need good food and a bed." },
  "s": { words: ["speak", "school", "start", "Spain", "student"], pairs: [], sentence: "Students speak Spanish at school." }
};
// Sonidos que suelen costar a los hispanohablantes (si todavía no hay datos tuyos).
const LAB_COMMON = ["θ", "v", "ɪ", "æ", "z", "ʃ", "ɹ", "ð"];
const labKey = p => { p = String(p || "").replace("ː", ""); if (p === "r") return "ɹ"; if (p === "ɝ" || p === "ɚ") return "ɜ"; return p; };
if (!PRON_TIPS["ɛ"]) PRON_TIPS["ɛ"] = { name: "E corta (bed)", how: "Como la “e” española, pero un poco más abierta y corta. No la conviertas en “ei”.", pair: "bed / bad · men / man" };
if (!PRON_TIPS["l"]) PRON_TIPS["l"] = { name: "L final (call)", how: "Al final de la palabra levanta la parte de atrás de la lengua: suena más oscura, casi “ul”.", pair: "call · feel · people" };
const labTip = k => PRON_TIPS[k] || { name: "/" + k + "/", how: "Escucha despacio, fíjate en la boca y repite exagerando el sonido.", pair: "" };

const lab = { on: false, sounds: [], resolveTap: null, tier: "g", helps: 0,
  hf: (() => { try { return localStorage.getItem("wtw_lab_hf") === "1"; } catch (e) { return false; } })() };
// Manos libres: comandos de voz (en inglés, que es lo que se reconoce): repeat, hint, skip, stop.
function labCmd(text) {
  const t = noAccents(text || "").trim();
  if (!t || t.split(" ").length > 3) return null;
  if (/^(stop|finish|end|terminar|para)( please)?$/.test(t)) return "stop";
  if (/^(skip|next|siguiente)( please)?$/.test(t)) return "skip";
  if (/^(hint|help|tip|pista|ayuda)( please)?$/.test(t)) return "hint";
  if (/^(repeat|again|one more time|repite|repetir)( please)?$/.test(t)) return "repeat";
  return null;
}
// Escucha una respuesta corta y devuelve el texto (Azure o el navegador).
async function labHear(ref) {
  if (cfg.pronunciation) {
    lab.listening = true;
    const wav = await recordWav(3500, null, 0.7);
    lab.listening = false;
    if (!lab.on || !wav.heard) return "";
    const fd = new FormData(); fd.append("text", ref); fd.append("audio", wav, "voz.wav");
    try { const r = await api("/pronunciation/assess", { method: "POST", body: fd }); return (r.assessment && r.assessment.recognized) || ""; } catch (e) { return ""; }
  }
  try { return (await browserListen())[0] || ""; } catch (e) { return ""; }
}
// Niveles por sonido: Guiado (te lo dan todo), Práctica (ayuda solo si la pides), Dominio (sin modelo, en frío).
const LAB_TIERS = {
  g: { label: "🧭 Guiado", how: "Te explico el sonido, lo oyes despacio y te corrijo en cada intento." },
  p: { label: "✍️ Práctica", how: "Lo oyes una vez a velocidad normal. La explicación y el modelo lento, solo si los pides." },
  d: { label: "🏆 Dominio", how: "Sin modelo: ves la palabra y la dices en frío, como en la vida real." },
};
function labHelp() { lab.helps++; const h = $("labHelps"); if (h) h.textContent = lab.helps; }
// Botones de ayuda (cuentan como ayuda) para Práctica y Dominio.
function labAids(text) {
  const box = $("labAids"); if (!box) return;
  if (lab.tier === "g" || !text) { box.innerHTML = ""; return; }
  const t = labTip(labKey(lab.phoneme));
  box.innerHTML = `<button type="button" class="linkish" id="labAidListen">🔊 Oír el modelo</button><button type="button" class="linkish" id="labAidTip">💡 Cómo se hace</button>`;
  $("labAidListen").onclick = () => { labHelp(); labSay(text, "en", true); };
  $("labAidTip").onclick = () => { labHelp(); const st = $("labStage"); if (st && !st.querySelector(".lab-how")) st.insertAdjacentHTML("beforeend", `<div class="lab-how"><p>${esc(t.how)}</p></div>`); labEs(t.how); };
}
function labSay(text, lang, slow) {
  if (!lab.on || !text) return Promise.resolve();
  lang = lang || "en";
  [text, lang] = uiSpeech(text, lang);
  if (useTts()) return playTts(text, lang, slow).catch(() => labBrowserSay(text, lang, slow));
  return labBrowserSay(text, lang, slow);
}
function labBrowserSay(text, lang, slow) {
  return new Promise(resolve => {
    if (!lab.on || !("speechSynthesis" in window)) return resolve();
    if (speechSynthesis.speaking || speechSynthesis.pending) speechSynthesis.cancel();
    const u = new SpeechSynthesisUtterance(text);
    u.lang = lang === "es" ? "es-ES" : "en-US"; u.rate = slow ? (lang === "es" ? 0.85 : 0.6) : (lang === "es" ? 1 : 0.9);
    if (lang === "es" && typeof esVoice !== "undefined" && esVoice) u.voice = esVoice; else if (lang !== "es" && voice) u.voice = voice;
    let done = false; const fin = () => { if (!done) { done = true; resolve(); } };
    u.onend = fin; u.onerror = fin; setTimeout(fin, 2500 + text.length * 130);
    speechSynthesis.speak(u);
  });
}
const labEs = t => labSay(t, "es");
function labStep(text, mode) { const s = $("labStep"); if (s) s.innerHTML = `<span class="hf-dot ${mode || ""}"></span>${esc(text)}`; }

function showLab(on) {
  if (!on) { lab.on = false; if (stopRecording) stopRecording(); $("labView").hidden = true; const back = lab.returnTo || "practice"; lab.returnTo = null; showTab(back); return; }
  if (hf.on) stopHF();
  ["queue", "main", "hfBar", "hello", "chatView", "quizView", "speakView", "progressView", "todayView", "pathView", "practiceView"].forEach(id => { if ($(id)) $(id).hidden = true; });
  $("labView").hidden = false;
  document.body.dataset.nav = "practice";
  document.querySelectorAll("#bottomNav [data-nav]").forEach(b => b.dataset.nav === "practice" ? b.setAttribute("aria-current", "page") : b.removeAttribute("aria-current"));
  window.scrollTo({ top: 0, behavior: "smooth" });
}

async function openLab(focusPhoneme) {
  showLab(true);
  $("labBody").innerHTML = '<p class="note">Cargando tus sonidos…</p>';
  try { lab.sounds = (await api("/pronunciation/sounds")).sounds; } catch (e) { lab.sounds = []; }
  if (focusPhoneme) return startLab(focusPhoneme);
  renderLabHome();
}
function renderLabHome() {
  const mine = lab.sounds.filter(s => DRILLS[labKey(s.phoneme)]);
  const seen = new Set(mine.map(s => labKey(s.phoneme)));
  const extra = LAB_COMMON.filter(k => !seen.has(k)).map(k => ({ phoneme: k, errors: 0, stage: 0, due: true, mastered: false, common: true }));
  const row = s => {
    const k = labKey(s.phoneme), t = labTip(k);
    const dots = [0, 1, 2, 3].map(i => `<i class="${i < s.stage ? "on" : ""}"></i>`).join("");
    const when = s.mastered ? "✅ Dominado" : s.due ? "Toca hoy" : "Próximo: " + new Date(s.next_practice + "T12:00").toLocaleDateString("es", { weekday: "short", day: "numeric" });
    const info = s.common ? "Difícil para hispanohablantes" : `${s.errors} ${s.errors === 1 ? "error" : "errores"}${s.last_word ? " · última: “" + esc(s.last_word) + "”" : ""}`;
    return `<li class="lab-row${s.due && !s.mastered ? " due" : ""}"><span class="ipa">/${esc(s.phoneme)}/</span>
      <div><b>${esc(t.name)}</b><small>${info}</small><span class="lab-tier t-${s.tier || "g"}">${LAB_TIERS[s.tier || "g"].label}</span><span class="dots" title="Talleres aprobados">${dots}</span></div>
      <div class="lab-act"><small>${when}</small><button type="button" class="${s.due && !s.mastered ? "primary" : ""}" data-lab="${esc(s.phoneme)}" data-tier="${esc(s.tier || "g")}">Practicar</button>${s.tier && s.tier !== "g" ? `<button type="button" class="linkish" data-lab="${esc(s.phoneme)}" data-tier="g" title="Repasar con toda la ayuda (no cambia tu nivel)">con guía</button>` : ""}</div></li>`;
  };
  const top = mine.find(s => s.due && !s.mastered) || mine[0];
  $("labBody").innerHTML = `<div class="kind"><span>🎯 Taller de pronunciación</span><span>unos 4 minutos por sonido</span></div>
    <h2 class="tr">${mine.length ? "Los sonidos que más te cuestan" : "Empecemos con los sonidos más difíciles"}</h2>
    <p class="note">${mine.length ? "Salen de tus grabaciones: cada vez que un sonido queda por debajo del 60%, se anota aquí." : "Todavía no tengo tus datos. Practica fichas con el micrófono y aquí aparecerán tus sonidos difíciles. Mientras, estos son los que más cuestan a los hispanohablantes."}</p>
    <label class="switch" for="labHf"><input type="checkbox" id="labHf" role="switch"${lab.hf ? " checked" : ""}> 🎧 Manos libres</label>
    <p class="note">Con manos libres contestas todo hablando y al terminar un sonido pasa solo al siguiente. Comandos en inglés: <b>repeat</b>, <b>hint</b>, <b>skip</b>, <b>stop</b>.</p>
    <details class="how-lab"><summary>Cómo funciona</summary><ol>
      <li><b>Cómo se hace:</b> dónde poner la lengua, los labios y el aire.</li>
      <li><b>Entrena el oído:</b> distingues pares de palabras que solo cambian en ese sonido. Si no lo oyes, no lo puedes decir.</li>
      <li><b>Imita despacio:</b> escuchas lento, repites, y la app evalúa <i>ese sonido</i>. Se repite hasta que sale.</li>
      <li><b>Contraste:</b> dices la palabra difícil frente a la que se confunde.</li>
      <li><b>En una frase:</b> lo usas dentro de una frase real.</li>
      <li><b>Repaso espaciado:</b> el taller vuelve mañana, en 3, 7 y 14 días. Con 4 aprobados el sonido queda dominado.</li></ol>
      <p><b>Niveles de cada sonido</b> (cada ayuda que pides cuenta):</p><ol>
      <li><b>${LAB_TIERS.g.label}:</b> ${LAB_TIERS.g.how} Si lo apruebas sin necesitar ninguna ayuda, saltas directo a Dominio.</li>
      <li><b>${LAB_TIERS.p.label}:</b> ${LAB_TIERS.p.how} Lo apruebas sin ayudas y pasas a Dominio.</li>
      <li><b>${LAB_TIERS.d.label}:</b> ${LAB_TIERS.d.how} Si fallas o pides ayuda dos veces seguidas, vuelves a Práctica. El sonido solo queda dominado con un taller de Dominio sin ayudas.</li></ol></details>
    ${top ? `<div class="row"><button type="button" class="primary" data-lab="${esc(top.phoneme)}">▶ Empezar con /${esc(top.phoneme)}/</button></div>` : ""}
    <ul class="lab-list">${mine.map(row).join("")}${extra.length ? `<li class="lab-sep">${mine.length ? "Otros sonidos difíciles para hispanohablantes" : ""}</li>` + extra.map(row).join("") : ""}</ul>
    ${!cfg.pronunciation && !SR ? '<p class="warnbox">Para evaluar tu voz hace falta Azure Speech o Google Chrome.</p>' : ""}
    <div class="row"><button type="button" id="labClose">Volver</button></div>`;
  $("labBody").querySelectorAll("[data-lab]").forEach(b => b.onclick = () => { unlockAudio(); startLab(b.dataset.lab, b.dataset.tier); });
  $("labClose").onclick = () => showLab(false);
  $("labHf").onchange = e => { lab.hf = e.target.checked; try { localStorage.setItem("wtw_lab_hf", lab.hf ? "1" : "0"); } catch (er) {} };
}

function labScreen(phoneme, stepName, idx) {
  const k = labKey(phoneme), t = labTip(k);
  const steps = ["Cómo se hace", "Entrena el oído", "Imita despacio", "Contraste", "En una frase"];
  $("labBody").innerHTML = `<div class="kind"><span>🎯 /${esc(phoneme)}/ · ${esc(t.name)}</span><span>${LAB_TIERS[lab.tier].label} · ayudas: <b id="labHelps">${lab.helps}</b> · ${idx + 1} de ${steps.length}</span></div>
    <ol class="lab-steps">${steps.map((s, i) => `<li class="${i < idx ? "done" : i === idx ? "cur" : ""}">${s}</li>`).join("")}</ol>
    <h3 class="lab-title">${esc(stepName)}</h3>
    <div class="focus-step" id="labStep"></div>
    <div id="labStage"></div>
    <div class="row lab-aids" id="labAids"></div>
    <div class="heard" id="labHeard"></div>
    <div class="row"><button type="button" id="labStop">Terminar</button></div>`;
  $("labStop").onclick = () => { lab.on = false; if (stopRecording) stopRecording(); if (lab.resolveTap) lab.resolveTap(null); openLab(); };
}

// Graba y evalúa. Devuelve { pct (del sonido), overall, silent }.
async function labAssess(text, phoneme, ms) {
  const out = $("labHeard");
  if (cfg.pronunciation) {
    labStep("🎙️ Tu turno: habla ahora", "listen");
    const wav = await recordWav(ms || 3500, null, /\s/.test(text) ? 1.0 : 0.6);
    if (!lab.on) return { silent: true };
    labStep("Evaluando…");
    const fd = new FormData(); fd.append("text", text); fd.append("phoneme", phoneme); fd.append("audio", wav, "voz.wav");
    let r; try { r = await api("/pronunciation/assess", { method: "POST", body: fd }); }
    catch (e) { labStep(e.message); if (/límite|configurada/i.test(e.message)) throw e; return { silent: true }; }
    if (out) showAzure(r, out);
    if (!r.assessment || r.assessment.status !== "Success") return { silent: true };
    if (lab.hf && labCmd(r.assessment.recognized)) return { pct: 0, cmd: labCmd(r.assessment.recognized) };
    const pct = r.target_score != null ? r.target_score : r.score;
    if (out && r.target_score != null) out.insertAdjacentHTML("afterbegin", `<p class="lab-target">Sonido /${esc(phoneme)}/: <b style="color:${pct >= LAB_PASS ? "var(--good)" : pct >= 60 ? "var(--warn)" : "var(--bad)"}">${pct}%</b></p>`);
    return { pct, overall: r.score };
  }
  if (!SR) throw new Error("Para evaluar tu voz hace falta Azure Speech o Google Chrome.");
  labStep("🎙️ Tu turno: habla ahora", "listen");
  let alts = []; try { alts = await browserListen(); } catch (e) { return { silent: true }; }
  if (lab.hf && labCmd(alts[0])) return { pct: 0, cmd: labCmd(alts[0]) };
  let best = null; alts.forEach(a => { const c = compare(text, a); if (!best || c.pct > best.pct) best = c; });
  if (out) verdict(out, best.pct, '<span class="note">Entendí: “' + esc(alts[0]) + '”</span>', best.toks.map(z => `<span class="tok ${z.ok ? "ok" : "miss"}">${esc(z.x)}</span>`).join(""));
  return { pct: best.pct, overall: best.pct };
}

// Un ejercicio: modelo → repites → evaluación, hasta que sale (o se agotan los intentos).
async function labDrill(text, phoneme, pass, showHtml) {
  const k = labKey(phoneme), t = labTip(k), isSentence = /\s/.test(text), tier = lab.tier;
  const stage = $("labStage"); if (stage) stage.innerHTML = showHtml || `<p class="lab-word">${esc(text)}</p>`;
  labAids(text);
  let best = 0;
  for (let i = 0; i < LAB_TRIES && lab.on; i++) {
    if (tier === "g") {
      // Guiado: el modelo lento en cada intento (y normal desde el tercero). Repetir con el modelo cuenta como ayuda.
      if (i) labHelp();
      labStep(i ? "Escucha otra vez" : "Escucha", "speak");
      await labSay(text, "en", true);
      if (i >= 2) { await labEs("Ahora a velocidad normal."); await labSay(text, "en"); }
    } else if (tier === "p" && i === 0) {
      labStep("Escucha una vez", "speak");
      await labSay(text, "en");
    } else {
      labStep(tier === "d" ? "Léela y dila" : "Otra vez, sin modelo");
    }
    if (!lab.on) return null;
    const r = await labAssess(text, phoneme, isSentence ? 7000 : 3500);
    if (!lab.on) return null;
    if (r.silent) { if (++lab.silent > 3) { await labEs("No te oigo. Revisa el micrófono y vuelve a intentarlo."); return -best || -1; } await labEs("No te oí. Acércate al micrófono."); i--; continue; }
    lab.silent = 0;
    if (r.cmd) {
      if (r.cmd === "stop") { lab.on = false; return null; }
      if (r.cmd === "skip") { await labEs("Saltamos esta."); return -best || -1; }
      labHelp();
      if (r.cmd === "hint") await labEs(t.how); else await labSay(text, "en", true);
      i--; continue;
    }
    best = Math.max(best, r.pct);
    if (r.pct >= pass && (!isSentence || (r.overall || 0) >= 60)) { await labEs(i ? pick(["¡Ahora sí!", "¡Esa es!", "¡Mucho mejor!"]) : pick(HF_PRAISE)); return r.pct; }
    labStep(`Sonido al ${r.pct}% · necesitas ${pass}%`);
    if (tier !== "g") { await labEs(r.pct >= pass - 10 ? "Casi. Otra vez." : "Otra vez."); continue; }
    // Retroalimentación distinta en cada intento (lo que dice la investigación: corregir algo concreto, no solo "otra vez").
    const fb = [
      `El sonido salió al ${r.pct} por ciento. Recuerda: ${firstSentence(t.how)}`,
      "Más despacio. Exagera la boca y alarga el sonido.",
      "Escúchalo lento y luego normal, y copia el ritmo.",
      isSentence ? "Divide la frase: di primero las dos primeras palabras y luego el resto, sin parar." : "Di la palabra dos veces seguidas, como un eco.",
    ];
    await labEs(r.pct >= pass - 10 ? "¡Casi! " + fb[Math.min(i, fb.length - 1)] : fb[Math.min(i, fb.length - 1)]);
  }
  if (lab.on) await labEs("Lo dejamos aquí por ahora. Vuelve mañana: con el sueño de por medio sale mejor.");
  return -best || -1;
}

// Manos libres: al terminar un sonido, sigue con el próximo que toca hoy (se puede parar).
async function labAutoNext(done) {
  try { lab.sounds = (await api("/pronunciation/sounds")).sounds; } catch (e) { return; }
  const next = lab.sounds.find(s => s.due && !s.mastered && s.phoneme !== done && DRILLS[labKey(s.phoneme)]);
  const box = $("labBody").querySelector(".done .row"); if (!box) return;
  lab.on = true; // para que hable
  if (!next) { await labEs("No quedan más sonidos para hoy. ¡Buen trabajo!"); lab.on = false; return; }
  box.insertAdjacentHTML("beforebegin", `<p class="banner" id="labNext">Siguiente: /${esc(next.phoneme)}/ en unos segundos… <button type="button" id="labNextStop">Parar aquí</button></p>`);
  let stop = false; $("labNextStop").onclick = () => { stop = true; lab.on = false; $("labNext").remove(); };
  await labEs("Seguimos con el siguiente sonido.");
  await new Promise(r => setTimeout(r, 2500));
  lab.on = false;
  if (!stop && $("labNext")) startLab(next.phoneme, next.tier);
}

async function startLab(phoneme, tier) {
  if (!cfg.pronunciation && !SR) { alertSide("Para evaluar tu voz hace falta Azure Speech o Google Chrome."); return; }
  const k = labKey(phoneme), d = DRILLS[k], t = labTip(k);
  if (!d) { alertSide("Todavía no tengo ejercicios para /" + phoneme + "/."); return; }
  const mine = lab.sounds.find(x => x.phoneme === phoneme);
  lab.on = true; lab.silent = 0; lab.helps = 0; lab.phoneme = phoneme;
  lab.tier = LAB_TIERS[tier] ? tier : (mine && LAB_TIERS[mine.tier] ? mine.tier : "g");
  const scores = [];
  const record = v => { if (v != null) scores.push(v); };
  try {
    // 1) Cómo se hace (solo en Guiado; en Práctica y Dominio está en «💡 Cómo se hace», que cuenta como ayuda)
    if (lab.tier === "g") {
    labScreen(phoneme, "Cómo se hace", 0);
    $("labStage").innerHTML = `<div class="lab-how"><p>${esc(t.how)}</p>${t.pair ? `<p class="pair">Escucha: ${esc(t.pair)}</p>` : ""}</div>`;
    labStep("Escucha la explicación", "speak");
    await labEs("Vamos a practicar " + t.name.replace(/\(.*\)/, "") + ". " + t.how);
    for (const w of d.words.slice(0, 2)) { await labSay(w, "en", true); await labSay(w, "en"); }
    } else {
      labScreen(phoneme, "Cómo se hace", 0);
      await labEs(lab.tier === "d" ? "Nivel Dominio: sin modelo. Lee y dilo tú." : "Nivel Práctica: lo oyes una vez. Si necesitas la explicación o el modelo lento, pídelo.");
    }
    if (!lab.on) return;

    // 2) Entrena el oído: pares mínimos hasta acertar 4 seguidos (máx. 12)
    if (d.pairs.length && lab.tier !== "d") {
      labScreen(phoneme, "Entrena el oído", 1);
      await labEs("Ahora entrena el oído. Te digo una palabra y tú tocas cuál oíste.");
      let streak = 0, n = 0, hits = 0;
      while (lab.on && streak < 4 && n < 12) {
        const pair = d.pairs[Math.floor(Math.random() * d.pairs.length)], said = pair[Math.random() < 0.5 ? 0 : 1];
        const opts = Math.random() < 0.5 ? pair : [pair[1], pair[0]];
        $("labStage").innerHTML = `<p class="note">¿Cuál oíste? <span class="faint">${streak}/4 seguidas</span></p>
          <div class="lab-pair">${opts.map(w => `<button type="button" data-w="${esc(w)}">${esc(w)}</button>`).join("")}</div>
          <button type="button" class="linkish" id="labAgain">🔊 Oír otra vez</button>`;
        $("labAgain").onclick = () => { labHelp(); labSay(said, "en"); };
        labStep("Escucha y toca la palabra", "speak");
        await labSay(said, "en");
        const pickW = await new Promise(res => {
          let done = false;
          const fin = v => { if (done) return; done = true; lab.resolveTap = null; if (lab.listening && stopRecording) stopRecording(); res(v); };
          lab.resolveTap = fin;
          $("labStage").querySelectorAll("[data-w]").forEach(b => b.onclick = () => fin(b.dataset.w));
          // Manos libres: también vale decir la palabra en voz alta ("repeat" la vuelve a decir).
          if (lab.hf) (async () => {
            for (let tries = 0; tries < 4 && !done && lab.on; tries++) {
              labStep("Di la palabra que oíste (o tócala)", "listen");
              const heard = norm(await labHear(opts[0]));
              if (done || !lab.on) return;
              const hit = opts.find(w => heard.includes(norm(w)[0]));
              if (hit && !opts.every(w => heard.includes(norm(w)[0]))) return fin(hit);
              if (labCmd(heard.join(" ")) === "stop") { lab.on = false; return fin(null); }
              if (labCmd(heard.join(" ")) === "repeat") { labHelp(); await labSay(said, "en"); tries--; }
            }
            if (!done) labStep("Toca la palabra que oíste");
          })();
        });
        lab.resolveTap = null; if (!lab.on || pickW == null) return;
        n++;
        const btn = $("labStage").querySelector(`[data-w="${CSS.escape(said)}"]`); if (btn) btn.classList.add("ok");
        if (pickW === said) { streak++; hits++; labStep("✅ ¡Bien!"); await labEs(pick(["Bien.", "Correcto.", "Eso es."])); }
        else {
          streak = 0; const wrong = $("labStage").querySelector(`[data-w="${CSS.escape(pickW)}"]`); if (wrong) wrong.classList.add("bad");
          labStep("❌ Era “" + said + "”"); await labEs("Era esta. Escucha las dos."); await labSay(pair[0], "en", true); await labSay(pair[1], "en", true);
        }
      }
      record(n ? Math.round(hits / n * 100) : null);
    }
    if (!lab.on) return;

    // 3) Imita despacio: palabras con el sonido
    labScreen(phoneme, "Imita despacio", 2);
    await labEs(lab.tier === "g" ? "Ahora imita. Te la digo despacio y la repites. Evalúo solo este sonido." : lab.tier === "p" ? "Te la digo una vez y la repites." : "Di cada palabra. Evalúo solo este sonido.");
    for (const w of d.words.slice(0, 3)) { if (!lab.on) return; record(await labDrill(w, phoneme, LAB_PASS)); }

    // 4) Contraste: la palabra con el sonido frente a la que se confunde
    if (d.pairs.length) {
      labScreen(phoneme, "Contraste", 3);
      await labEs(lab.tier === "d" ? "Contraste. Di la primera palabra, la que tiene el sonido." : "Contraste. Escucha las dos y di la primera, la que tiene el sonido.");
      for (const [a, b] of d.pairs.slice(0, 2)) {
        if (!lab.on) return;
        if (lab.tier !== "d") { await labSay(a, "en", lab.tier === "g"); await labSay(b, "en", lab.tier === "g"); }
        record(await labDrill(a, phoneme, LAB_PASS, `<p class="lab-word">${esc(a)} <span class="faint">≠ ${esc(b)}</span></p>`));
      }
    }

    // 5) En una frase
    if (!lab.on) return;
    labScreen(phoneme, "En una frase", 4);
    await labEs("Último paso. Úsalo en una frase.");
    record(await labDrill(d.sentence, phoneme, LAB_SENT_PASS, `<p class="lab-sentence">${esc(d.sentence)}</p>`));
    if (!lab.on) return;

    // Resultado y próximo repaso
    const passedItems = scores.filter(s => s > 0).length, total = scores.length;
    const avg = Math.round(scores.map(Math.abs).reduce((a, b) => a + b, 0) / Math.max(1, total));
    const passed = total > 0 && passedItems / total >= 0.8;
    let res = null; try { res = await api("/pronunciation/sounds/result", { method: "POST", body: { phoneme, passed, score: Math.min(100, avg), tier: lab.tier, helps: lab.helps } }); } catch (e) {}
    const order = ["g", "p", "d"], up = res && order.indexOf(res.tier) > order.indexOf(res.previous_tier), down = res && order.indexOf(res.tier) < order.indexOf(res.previous_tier);
    const tierMsg = !res ? "" : up ? `<p class="banner ok">⬆️ Subes a <b>${LAB_TIERS[res.tier].label}</b>${res.previous_tier === "g" && res.tier === "d" ? " directo: no necesitaste ninguna ayuda" : ""}.</p>`
      : down ? `<p class="warnbox">Vuelves a <b>${LAB_TIERS[res.tier].label}</b> un tiempo: en Dominio necesitaste ayuda dos veces seguidas.</p>`
      : `<p class="note">Sigues en <b>${LAB_TIERS[res.tier].label}</b>${res.tier !== "d" && passed ? ". Para subir, apruébalo sin pedir ayudas" : ""}.</p>`;
    const when = res ? (res.days === 1 ? "mañana" : "en " + res.days + " días") : "mañana";
    $("labBody").innerHTML = `<div class="kind"><span>🎯 /${esc(phoneme)}/ · ${esc(t.name)}</span><span>Resultado</span></div>
      <div class="done"><div class="big">${passed ? (res && res.mastered ? "🏆" : "🎉") : "💪"}</div>
      <h2>${passed ? (res && res.mastered ? "¡Sonido dominado!" : "¡Taller aprobado!") : "¡Buen trabajo, sigue así!"}</h2>
      <p class="note">${passedItems} de ${total} ejercicios logrados · promedio ${avg}% · ${lab.helps} ${lab.helps === 1 ? "ayuda" : "ayudas"}</p>
      ${tierMsg}
      <p class="note">${passed ? `Lo repasamos <b>${when}</b> para que se quede fijo${res ? ` (${res.stage} de 4 aprobados).` : "."}` : `Lo repetimos <b>${when}</b>. Dormir entre prácticas ayuda a fijar el movimiento.`}</p>
      <div class="row"><button type="button" class="primary" id="labAgainAll">Repetir ahora</button><button type="button" id="labHome">Otros sonidos</button><button type="button" id="labBack">Volver</button></div></div>`;
    if (passed) confetti();
    $("labAgainAll").onclick = async () => { unlockAudio(); try { lab.sounds = (await api("/pronunciation/sounds")).sounds; } catch (e) {} startLab(phoneme); };
    $("labHome").onclick = () => openLab();
    $("labBack").onclick = () => showLab(false);
    await labEs(passed ? "¡Excelente! Lo repasamos " + when + "." : "Buen esfuerzo. Lo repetimos " + when + ".");
    const wasOn = lab.on;
    lab.on = false;
    try { stats = await api("/stats"); renderSide(); } catch (e) {}
    if (lab.hf && wasOn) await labAutoNext(phoneme);
  } catch (e) {
    lab.on = false; alertSide(e.message);
    if ($("labStage")) $("labStage").innerHTML = `<p class="warnbox">${esc(e.message)}</p>`;
  }
}
$("labBtn").onclick = () => { unlockAudio(); openLab(); };
