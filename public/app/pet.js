/* Brainy en la web (como en la app, mobile/lib/features/pet): la mascota que aprende lo que tú aprendes.
   - Hoy: su tarjeta; con «Modo Brainy» la pantalla de Hoy ES la mascota (barras de corazones y botones de cuidado).
   - Pantalla de Brainy: etapa, cuidados, su cerebro (zonas) y su historia.
   - Nacimiento (una vez): animación, «¿Cómo me quieres llamar?» y el color.
   - Ajustes → Brainy: Modo Brainy, nombre y color.
   El dibujo y las animaciones están en pet-draw.js (W2WPetDraw). Si no cargara, sale un 🧠 y todo lo demás funciona.
   API: GET /pet, PUT /pet/name {name|null}, PUT /pet/color {color|null}, POST /pet/{feed|play|clean|medicine} → {go},
        POST /experiments/brainy {mode, changed, opened?} (solo si el servidor propone un modo: brainy_default de /me).
   Sin atributos de evento en el HTML (CSP): los botones llevan data-pet="…" y aquí se escuchan. */
"use strict";
const pet = { data: null, loaded: false, thanks: null, figs: [], birth: null, busy: null, msg: "", sent: null, naming: false };

// ---------- textos (los mismos que la app) ----------
const PET_STAGE = { spark: "Chispa", sprout: "Brote", curious: "Aprendiz", chatty: "Voz", wise: "Mente brillante" };
const petStageName = key => PET_STAGE[key] || "Etapa";
const PET_REGIONS = [["words", "Palabras que conoce", "#E6A64A"], ["memory", "Palabras que recuerda bien", "#7C9CFF"], ["path", "Unidades del Camino", "#4AC487"], ["habit", "Días seguidos", "#F07A9A"]];
const PET_NEEDS = [["food", "Comida", "#E6A64A"], ["joy", "Ánimo", "#F07A9A"], ["clean", "Limpieza", "#7C9CFF"], ["health", "Salud", "#4AC487"]];
const PET_ACTIONS = [["feed", "🍎", "Comer", "Palabras nuevas"], ["play", "🎧", "Jugar", "Oído"], ["clean", "🧽", "Limpiar", "Repasos de hoy"], ["medicine", "💊", "Medicina", "Un sonido"]];
const PET_NOTHING = { feed: "Hoy ya no quedan palabras para Brainy. Prueba a jugar.", clean: "Todo limpio: no hay repasos pendientes." };
const PET_MOOD = {
  hibernating: "Brainy está hibernando. Haz cualquier ejercicio y despierta.", asleep: "Brainy duerme. Si estudias ahora, mañana lo nota.",
  sick: "Brainy no se siente bien. Su medicina es practicar un sonido.", hungry: "Brainy tiene hambre de palabras.",
  messy: "Hay repasos pendientes por ordenar.", bored: "Brainy quiere jugar.", happy: "Brainy está feliz.",
};
// Lo que dice, siempre en inglés muy fácil (leerlo también es practicar).
const PET_BUBBLE = { hibernating: "Zzz…", asleep: "Zzz…", sick: "I feel sick.", hungry: "I'm hungry!", messy: "What a mess!", bored: "Let's play!", happy: "I'm happy!" };
const PET_THANKS = { feed: "Yum! Thank you!", play: "That was fun!", clean: "So clean!", medicine: "I feel better!" };
const PET_FORM = { talker: "Parlanchina", listener: "Orejona", scholar: "Sabia", balanced: "Equilibrada" };
const PET_COLOR_NAMES = { null: "Neutro", blue: "Azul", purple: "Morado", pink: "Rosa", coral: "Coral", orange: "Naranja", green: "Verde", teal: "Turquesa" };

// ---------- datos ----------
async function petLoad() {
  try { const j = await api("/pet"); pet.data = j && j.stage && j.regions ? j : null; } catch (e) { pet.data = null; }
  pet.loaded = true;
  return pet.data;
}
const petCare = () => pet.data && pet.data.care && pet.data.care.needs ? pet.data.care : null;
function petRegion(k) { const r = pet.data && pet.data.regions && pet.data.regions[k] || {}; return { count: r.count || 0, target: r.target || 0, level: Math.max(0, Math.min(1, r.level || 0)) }; }

// ---------- Modo Brainy (se guarda en el navegador; sin tocarlo, lo que proponga el servidor) ----------
function petModeStored() { try { const v = localStorage.getItem("wtw_brainy_mode"); return v === "1" || v === "0" ? v : null; } catch (e) { return null; } }
function petModeOn() { const v = petModeStored(); return v ? v === "1" : !!(profile && profile.brainy_default); }
function petSetMode(on) { try { localStorage.setItem("wtw_brainy_mode", on ? "1" : "0"); } catch (e) {} petReport(); }
/** Experimento A/B: solo si el servidor propone un modo. No repite lo mismo; si falla, se ignora. */
async function petReport(opened) {
  if (!profile || profile.brainy_default == null) return;
  const body = { mode: petModeOn(), changed: petModeStored() !== null };
  const key = body.mode + "|" + body.changed;
  if (!opened && pet.sent === key) return;
  try { await api("/experiments/brainy", { method: "POST", body: opened ? Object.assign(body, { opened: true }) : body }); if (!opened) pet.sent = key; } catch (e) {}
}

// ---------- dibujo ----------
/** Un hueco para la figura: <canvas data-petfig="tamaño">. petMountAll() lo dibuja. */
const petFig = (size, cls) => `<canvas class="pet-fig ${cls || ""}" data-petfig="${size}" style="width:${size}px;height:${size}px" role="img" aria-label="${esc((pet.data && pet.data.name) || "Brainy")}"></canvas>`;
function petMountAll(root) {
  pet.figs = pet.figs.filter(f => { if (f.canvas.isConnected) return true; try { f.ctl.destroy(); } catch (e) {} return false; });
  (root || document).querySelectorAll("canvas[data-petfig]").forEach(c => {
    if (c.dataset.mounted || !pet.data) return;
    c.dataset.mounted = "1";
    const size = +c.dataset.petfig;
    if (!window.W2WPetDraw) { c.replaceWith(Object.assign(document.createElement("span"), { className: "pet-emoji", textContent: "🧠", style: `font-size:${Math.round(size * 0.6)}px` })); return; }
    try { pet.figs.push({ canvas: c, ctl: W2WPetDraw.mount(c, pet.data, { size, fit: size < 120 }) }); } catch (e) { console.error(e); }
  });
}
function petRefreshFigs() { pet.figs.forEach(f => { try { f.ctl.update(pet.data); } catch (e) {} }); }

function petHearts(count, max, color, label) {
  const s = 18, path = "M9 16.6C-1.4 9.8 1.8 -1.8 9 5c7.2-6.8 10.4 4.8 0 11.6z";
  return `<span class="pet-hearts" role="img" aria-label="${esc(label)}: ${count} de ${max}">${Array.from({ length: max }, (_, i) =>
    `<svg width="${s}" height="${s}" viewBox="0 0 18 18" aria-hidden="true"><path d="${path}" fill="${i < count ? color : "var(--line)"}"/></svg>`).join("")}</span>`;
}
function petWithBubble(size) {
  const c = petCare(), text = pet.thanks ? PET_THANKS[pet.thanks] : (c ? PET_BUBBLE[c.mood] : null);
  return `<div class="pet-stage" style="width:${Math.round(size * 1.25)}px;height:${size}px">${petFig(size)}${text ? `<span class="pet-bubble" lang="en">${esc(text)}</span>` : ""}</div>`;
}
function petCarePanel() {
  const c = petCare(); if (!c) return "";
  const max = (c.needs.food && c.needs.food.max) || 4;
  const want = { feed: c.mood === "hungry", play: c.mood === "bored", clean: c.mood === "messy", medicine: !!c.sick };
  return `<div class="pet-panel">
    <b>${esc(PET_MOOD[c.mood] || "Brainy está bien.")}</b>
    <p class="note">Cuidarla es estudiar: cada botón abre un ejercicio.</p>
    ${PET_NEEDS.map(([k, label, color]) => `<div class="pet-need"><span>${esc(label)}</span>${petHearts(Math.max(0, Math.min(max, (c.needs[k] || {}).hearts ?? max)), max, color, label)}</div>`).join("")}
    <div class="pet-actions">${PET_ACTIONS.map(([k, emoji, name, hint]) => `<button type="button" class="pet-act${want[k] ? " want" : ""}" data-pet="act" data-act="${k}" aria-label="${esc(name)}: ${esc(hint)}"${pet.busy ? " disabled" : ""}>
      <span class="e${pet.busy === k ? " busy" : ""}" aria-hidden="true">${emoji}</span><b>${esc(name)}</b><small>${esc(hint)}</small></button>`).join("")}</div>
    ${pet.msg ? `<p class="note" aria-live="polite">${esc(pet.msg)}</p>` : ""}
  </div>`;
}

// ---------- Hoy: tarjeta y Modo Brainy ----------
/** La tarjeta de Brainy en Hoy (si no hay mascota, no ocupa sitio). */
function petTodayCard() {
  const p = pet.data; if (!p) return "";
  const words = petRegion("words").count, prog = Math.round(Math.max(0, Math.min(1, p.stage.progress || 0)) * 100);
  return `<button type="button" class="td-link pet-card" data-pet="open">${petFig(72)}
    <span style="flex:1;display:grid;gap:4px"><small class="note">${esc(p.name)} · ${esc(petStageName(p.stage.key))}</small>
    <b>${words === 0 ? "Enséñale tu primera palabra" : `Ya sabe ${words} ${words === 1 ? "palabra" : "palabras"} gracias a ti`}</b>
    <span class="sp-bar"><i style="width:${prog}%"></i></span></span></button>`;
}
/** Con Modo Brainy, Hoy es la mascota. Devuelve true si la dibujó (y Hoy no dibuja lo de siempre). */
function petHomeRender(el) {
  if (!petModeOn() || !petCare() || td.classic) return false;
  const p = pet.data;
  el.innerHTML = `<div class="pet-home">
    <p class="note pet-title">${esc(p.name)} · ${esc(petStageName(p.stage.key))}</p>
    ${petWithBubble(220)}
    ${petCarePanel()}
    <button type="button" class="td-go pet-session" data-pet="classic">Mi sesión de hoy</button>
    <button type="button" class="linkish" data-pet="open">Ver su cerebro y su historia</button></div>`;
  petMountAll(el);
  return true;
}

// ---------- pantalla de Brainy ----------
async function petOpen() {
  const el = $("petBody"); if (!el) return;
  if (!pet.data) el.innerHTML = '<p class="note">Cargando a Brainy…</p>';
  await petLoad();
  petRender();
  petReport(true);
}
function petRender() {
  const el = $("petBody"); if (!el) return;
  const p = pet.data;
  if (!p) { el.innerHTML = `<div class="kind"><span>Brainy</span></div><p class="note">Brainy está descansando. Vuelve en un rato.</p><button type="button" data-pet="back">Volver</button>`; return; }
  const c = petCare(), last = p.stage.next == null, toNext = last ? 0 : Math.max(0, p.stage.next - p.points);
  const lit = window.W2WPetDraw && W2WPetDraw.litCount ? W2WPetDraw.litCount(p) : null;
  const form = c && PET_FORM[c.form], leaning = c && PET_FORM[c.leaning];
  el.innerHTML = `<div class="kind"><span>Brainy</span><button type="button" class="linkish" data-pet="back">Volver</button></div>
    <div class="pet-page">
    ${c ? petWithBubble(240) : `<div class="pet-stage">${petFig(240)}</div>`}
    <h2 class="pet-stage-name">${esc(petStageName(p.stage.key))}</h2>
    <p class="note pet-c">Etapa ${(p.stage.index || 0) + 1} de ${p.stage.count || 5}</p>
    <span class="sp-bar pet-bar"><i style="width:${Math.round((p.stage.progress || 0) * 100)}%"></i></span>
    <p class="note pet-c">${last ? "Brainy ya llegó a su última etapa. Sigue encendiendo su cerebro." : `${toNext === 1 ? "Falta 1 punto" : `Faltan ${toNext} puntos`} para crecer`}</p>
    ${petCarePanel()}
    <div class="pet-panel"><b>Su cerebro</b>
      ${lit ? `<p class="note">${lit.lit} de ${lit.total} neuronas encendidas</p>` : ""}
      ${PET_REGIONS.map(([k, label, color]) => { const s = petRegion(k); return `<div class="pet-skill"><span><i style="background:${color}"></i>${esc(label)}</span><b>${s.count} / ${s.target}</b>
        <span class="sp-bar"><i style="width:${Math.round(s.level * 100)}%;background:${color}"></i></span></div>`; }).join("")}
    </div>
    ${c ? `<div class="pet-panel"><b>Su historia</b>
      <span>${c.days === 1 ? "La cuidaste 1 día" : `La cuidaste ${c.days || 0} días`}</span>
      <span class="note">${form ? `Su forma adulta: <b>${esc(form)}</b>` : leaning ? `De adulta va para: <b>${esc(leaning)}</b>` : "Su forma adulta depende de lo que más practiques: hablar, oír o palabras."}</span>
      ${(c.history || []).map(h => `<div class="pet-need"><span>${esc(petStageName(h.stage))}</span><span class="note">${esc(h.at)}</span></div>`).join("")}
    </div>` : ""}
    <p class="note pet-c">Brainy aprende lo que tú aprendes: cada palabra, cada unidad y cada día que estudias enciende sus neuronas.</p>
    <p class="note pet-c">Brainy siempre te espera: lo que ya sabe no se le olvida.</p></div>`;
  petMountAll(el);
}

// ---------- botones de cuidado ----------
/** Qué toca con cada botón si no se puede preguntar al servidor (la misma regla que él usa). */
function petLocalGo(a, plan) {
  if (a === "feed") return plan.new.length ? "new" : plan.reviews.length ? "reviews" : "";
  if (a === "play") return (plan.ear || []).length ? "ear" : "sound";
  if (a === "clean") return plan.reviews.length ? "reviews" : plan.mistakes.length ? "mistakes" : "";
  return "sound";
}
function petSteps(go, plan) {
  if (go === "new") return plan.new.map(c => ({ type: "new", card: c }));
  if (go === "reviews") return plan.reviews.map(c => ({ type: "review", card: c }));
  if (go === "ear") return (plan.ear || []).map(e => ({ type: "ear", item: e }));
  if (go === "mistakes") return plan.mistakes.length ? [{ type: "mistakes" }] : [];
  if (go === "sound") {
    const s = tdSound(plan), ph = s ? s.phoneme : ["θ", "v", "ɪ", "æ", "z"][new Date().getDate() % 5];
    return DRILLS[labKey(ph)] ? DRILLS[labKey(ph)].words.slice(0, 2).map(w => ({ type: "sound", phoneme: ph, word: w })) : [];
  }
  return [];
}
async function petAct(a) {
  if (pet.busy) return;
  pet.busy = a; pet.msg = ""; pet.thanks = null; petRerender();
  const name = (PET_ACTIONS.find(x => x[0] === a) || [])[2];
  let today = null, go = null;
  try { today = await api("/session/today"); td.data = today; } catch (e) {}
  try { const r = await api("/pet/" + a, { method: "POST" }); if (r && "go" in r) go = r.go; } catch (e) {}
  let steps = [];
  if (today) {
    steps = petSteps(go != null ? go : petLocalGo(a, today.plan), today.plan);
    // Lo que dijo el servidor ya no está en lo de hoy (datos de hace un rato): decide la web.
    if (!steps.length && go) steps = petSteps(petLocalGo(a, today.plan), today.plan);
  }
  pet.busy = null;
  if (!steps.length) { pet.msg = PET_NOTHING[a] || "Ahora no se puede. Inténtalo en un rato."; petRerender(); return; }
  const xp0 = today.xp.xp, from = currentTab;
  sessRun(steps, { title: name, onEnd: async () => {
    showTab(from === "pet" ? "pet" : "today");
    try { const after = await api("/session/today"); td.data = after; if (after.xp.xp > xp0) pet.thanks = a; } catch (e) {}
    await petLoad(); petRerender();
  } });
}
/** Vuelve a dibujar donde esté la mascota ahora. */
function petRerender() {
  if (currentTab === "pet") petRender();
  else if (currentTab === "today" && typeof tdRender === "function") tdRender();
}

// ---------- nacimiento ----------
function petMaybeBirth() {
  const p = pet.data;
  if (!p || p.welcomed !== false || pet.birth || sessionStorageGet("wtw_pet_birth_seen")) return;
  const box = document.createElement("div");
  box.className = "pet-birth"; box.setAttribute("role", "dialog"); box.setAttribute("aria-modal", "true"); box.setAttribute("aria-label", "Nace tu mascota");
  box.innerHTML = `<div class="pet-birth-anim" id="petBirthAnim"></div><div class="pet-birth-ui" id="petBirthUi" hidden></div>`;
  document.body.appendChild(box); document.body.style.overflow = "hidden";
  pet.birth = { box, step: "anim", name: null, color: p.color || null, msg: "", busy: false, ctl: null };
  const done = () => petBirthStep("name");
  if (window.W2WPetDraw && W2WPetDraw.birth) {
    try { pet.birth.ctl = W2WPetDraw.birth($("petBirthAnim"), p, { onDone: done, below: 16 }); } catch (e) { console.error(e); done(); }
  } else done();
}
function sessionStorageGet(k) { try { return sessionStorage.getItem(k); } catch (e) { return null; } }
function petBirthStep(step) {
  const b = pet.birth; if (!b) return;
  b.step = step;
  const ui = $("petBirthUi"); ui.hidden = false;
  const newborn = (pet.data.stage.index || 0) === 0 && petRegion("words").count === 0;
  if (step === "name") {
    ui.innerHTML = `<h2>${newborn ? "¡Hola! Acabo de nacer." : "¡Hola! Soy tu mascota."}</h2>
      <p>¿Cómo me quieres llamar?</p>
      <input type="text" id="petBirthName" maxlength="20" autocomplete="off" placeholder="Brainy" aria-label="Nombre de tu mascota" value="${esc(b.name || "")}">
      ${b.msg ? `<p class="warnbox">${esc(b.msg)}</p>` : ""}
      <button type="button" class="primary" data-pet="birth-name"${b.busy ? " disabled" : ""}>${b.busy ? "Guardando…" : "Ponerle ese nombre"}</button>
      <button type="button" class="linkish" data-pet="birth-later">Luego</button>`;
    const inp = $("petBirthName"); inp.focus(); inp.onkeydown = e => { if (e.key === "Enter") petBirthName(false); };
  } else if (step === "color") {
    ui.innerHTML = `<h2>${b.name ? `¡Me llamo ${esc(b.name)}!` : "¡Hola! Soy Brainy."}</h2>
      <p>¿De qué color quieres que sea?</p>${petSwatches(b.color, "birth-color")}
      <p>Tengo hambre de palabras. ¿Me enseñas la primera?</p>
      <button type="button" class="primary" data-pet="birth-end">Empezar</button>`;
  }
}
async function petBirthName(later) {
  const b = pet.birth; if (!b || b.busy) return;
  const name = later ? null : ($("petBirthName").value || "").replace(/\s+/g, " ").trim();
  if (!later && name.length < 2) { b.msg = "Escribe un nombre de al menos 2 letras."; return petBirthStep("name"); }
  b.busy = true; b.msg = ""; petBirthStep("name");
  try { const j = await api("/pet/name", { method: "PUT", body: { name } }); if (j && j.stage) pet.data = j; b.name = later ? null : pet.data.name; b.busy = false; petBirthStep("color"); }
  catch (e) { b.busy = false; b.msg = e.message; petBirthStep("name"); }
}
function petBirthEnd() {
  const b = pet.birth; if (!b) return;
  try { b.ctl && b.ctl.destroy(); } catch (e) {}
  b.box.remove(); document.body.style.overflow = ""; pet.birth = null;
  try { sessionStorage.setItem("wtw_pet_birth_seen", "1"); } catch (e) {}
  petRerender();
}

// ---------- color ----------
function petColorList() {
  if (window.W2WPetDraw && W2WPetDraw.colors) return W2WPetDraw.colors.map(c => ({ key: c.key || null, hex: c.hex }));
  return [null, "blue", "purple", "pink", "coral", "orange", "green", "teal"].map(k => ({ key: k, hex: "" }));
}
function petSwatches(current, kind) {
  return `<div class="pet-swatches" role="radiogroup" aria-label="Color de tu mascota">${petColorList().map(c =>
    `<button type="button" class="pet-sw${(c.key || null) === (current || null) ? " on" : ""}" role="radio" aria-checked="${(c.key || null) === (current || null)}" data-pet="${kind}" data-color="${c.key || ""}" title="${esc(PET_COLOR_NAMES[c.key] || c.key)}" aria-label="${esc(PET_COLOR_NAMES[c.key] || c.key)}" style="${c.hex ? `background:${c.hex}` : ""}"></button>`).join("")}</div>`;
}
async function petSetColor(key, where) {
  const old = pet.data.color || null; if ((key || null) === old) return;
  pet.data.color = key; petRefreshFigs();   // se ve al momento
  if (pet.birth && pet.birth.ctl && pet.birth.ctl.setColor) try { pet.birth.ctl.setColor(key); } catch (e) {}
  if (where === "birth-color") { pet.birth.color = key; petBirthStep("color"); } else petSettingsRender();
  try { const j = await api("/pet/color", { method: "PUT", body: { color: key } }); if (j && j.stage) pet.data = j; }
  catch (e) { pet.data.color = old; petRefreshFigs(); pet.msg = e.message; petSettingsRender(); }
}

// ---------- Ajustes → Brainy ----------
async function petSettingsRender() {
  const box = $("petSettings"); if (!box) return;
  if (!pet.loaded) await petLoad();
  const p = pet.data;
  box.hidden = !p; if (!p) return;
  box.innerHTML = `<h3 class="acct-h">Brainy</h3>
    <label class="inl" for="petModeOn">Modo Brainy <input type="checkbox" id="petModeOn"${petModeOn() ? " checked" : ""}></label>
    <p class="note">Hoy muestra a tu mascota: cuidarla es estudiar. La sesión de siempre sigue a un toque.</p>
    ${pet.naming ? `<label class="inl" for="petNameIn">Nombre de tu mascota <input type="text" id="petNameIn" maxlength="20" value="${esc(p.name)}" autocomplete="off"></label>
      <div class="row"><button type="button" class="primary" data-pet="name-save">Guardar</button><button type="button" data-pet="name-cancel">Cancelar</button></div>`
    : `<div class="row"><button type="button" data-pet="name-edit">Nombre de tu mascota: <b>${esc(p.name)}</b></button></div>`}
    <span>Color de tu mascota</span>${petSwatches(p.color, "set-color")}
    ${pet.msg ? `<p class="note" aria-live="polite">${esc(pet.msg)}</p>` : ""}`;
  $("petModeOn").onchange = e => { petSetMode(e.target.checked); td.classic = false; };
}
async function petSaveName() {
  const name = ($("petNameIn").value || "").replace(/\s+/g, " ").trim();
  if (name.length < 2) { pet.msg = "Escribe un nombre de al menos 2 letras."; return petSettingsRender(); }
  try { const j = await api("/pet/name", { method: "PUT", body: { name } }); if (j && j.stage) pet.data = j; pet.naming = false; pet.msg = ""; }
  catch (e) { pet.msg = e.message; }
  petSettingsRender();
}

// ---------- clics ----------
document.addEventListener("click", e => {
  const b = e.target.closest("[data-pet]"); if (!b) return;
  const k = b.dataset.pet;
  if (k === "open") showTab("pet");
  else if (k === "back") showTab("today");
  else if (k === "classic") { td.classic = true; tdRender(); }
  else if (k === "act") { unlockAudio(); petAct(b.dataset.act); }
  else if (k === "birth-name") petBirthName(false);
  else if (k === "birth-later") petBirthName(true);
  else if (k === "birth-color" || k === "set-color") petSetColor(b.dataset.color || null, k);
  else if (k === "birth-end") petBirthEnd();
  else if (k === "name-edit") { pet.naming = true; pet.msg = ""; petSettingsRender(); }
  else if (k === "name-cancel") { pet.naming = false; pet.msg = ""; petSettingsRender(); }
  else if (k === "name-save") petSaveName();
});
// Tocar la animación del nacimiento la adelanta.
document.addEventListener("click", e => { if (pet.birth && pet.birth.step === "anim" && e.target.closest("#petBirthAnim") && pet.birth.ctl && pet.birth.ctl.skip) pet.birth.ctl.skip(); });
