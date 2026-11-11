/* Word to Word · Panel de progreso: qué hacer hoy, nivel, vocabulario, hablar, pronunciación y errores. */
"use strict";

const pg = { data: null, error: "", ach: null, league: null };
const ACH_ICON = {
  flag: '<path d="M5 21V4h11l-2 4 2 4H5"/>', fire: '<path d="M12 2c1 4 5 5.5 5 11a5 5 0 0 1-10 0c0-2.5 1.2-4 2.5-5.2.2 1.8 1 3 2.2 3.4C11 8.6 11 5 12 2z"/>',
  target: '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1"/>', book: '<path d="M4 4h7a3 3 0 0 1 3 3v13a2 2 0 0 0-2-2H4zM20 4h-6"/><path d="M20 4v14h-6"/>',
  mic: '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/>', chat: '<path d="M21 12a8 8 0 0 1-11.6 7.1L4 20l1-4.6A8 8 0 1 1 21 12z"/>',
  bolt: '<path d="M13 2 4 14h7l-1 8 9-12h-7z"/>', ear: '<path d="M7 9a5 5 0 0 1 10 0c0 3-3 4-3 7a3 3 0 0 1-6 0"/>', check: '<path d="m5 12 5 5 9-10"/>',
  map: '<path d="M9 4 3 6v14l6-2 6 2 6-2V4l-6 2z"/>', trophy: '<path d="M8 21h8M12 17v4M7 4h10v5a5 5 0 0 1-10 0zM7 6H4a3 3 0 0 0 3 4M17 6h3a3 3 0 0 1-3 4"/>',
};
const achIcon = k => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ACH_ICON[k] || ACH_ICON.check}</svg>`;
const pgNum = n => String(n ?? "—").replace(".", ",");

async function pgOpen() {
  const el = $("progressBody"); if (!el) return;
  if (!pg.data) el.innerHTML = '<p class="note">Cargando tu progreso…</p>';
  try {
    const [d, a, l] = await Promise.all([api("/progress"), api("/achievements").catch(() => null), api("/league").catch(() => null)]);
    pg.data = d; pg.ach = a; pg.league = l; pg.error = "";
  } catch (e) { pg.error = e.message; }
  pgRender();
}

// Línea pequeña (de la más vieja a la más nueva) para ver la tendencia.
function pgSpark(values, invert) {
  const v = (values || []).filter(x => x != null);
  if (v.length < 2) return '<span class="note">Aún no hay datos suficientes.</span>';
  const w = 160, h = 40, min = Math.min(...v), max = Math.max(...v), span = max - min || 1;
  const pts = v.map((x, i) => `${Math.round(i / (v.length - 1) * w)},${Math.round(h - 4 - (x - min) / span * (h - 8))}`).join(" ");
  const better = invert ? v[v.length - 1] < v[0] : v[v.length - 1] > v[0];
  return `<svg class="pg-spark ${better ? "up" : "down"}" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" aria-hidden="true"><polyline points="${pts}" fill="none" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round"/></svg>`;
}
function pgBars(items, max, cls) {
  max = Math.max(1, max || Math.max(...items.map(i => i.value)));
  return `<div class="pg-bars ${cls || ""}">${items.map(i => `<div class="pg-bar" title="${esc(i.title || "")}"><span class="pg-c"><i style="height:${Math.round(i.value / max * 100)}%"></i></span><small>${esc(i.label)}</small></div>`).join("")}</div>`;
}

function pgRender() {
  const el = $("progressBody"); if (!el) return;
  const d = pg.data;
  if (!d) { el.innerHTML = `<p class="warnbox">${esc(pg.error || "No se pudo cargar tu progreso.")}</p>`; return; }
  const v = d.vocab, s = d.speaking, m = d.mistakes, lv = d.level || {};
  const TIER = { g: "🧭 Guiado", p: "✍️ Práctica", d: "🏆 Dominio" };

  let html = `<div class="kind"><span>📊 Tu progreso</span><span>${esc(new Date(d.today + "T12:00").toLocaleDateString("es", { day: "numeric", month: "short" }))}</span></div>`;
  if (pg.error) html += `<p class="warnbox">${esc(pg.error)}</p>`;

  // Hoy
  html += `<section class="pg-sec"><h3>Lo que te falta hoy</h3>`;
  html += d.todo.length ? `<ul class="pg-todo">${d.todo.map((t, i) => `<li><span class="pg-ic">${t.icon}</span><span>${esc(t.text)}</span>${t.action ? `<button type="button" data-pg="${i}">Ir</button>` : ""}</li>`).join("")}</ul>`
    : '<p class="banner ok">¡Todo hecho por hoy! 🎉 Vuelve mañana.</p>';
  html += `</section>`;

  // Escalera de español
  if (d.spanish) html += spanishSection(d.spanish);

  // Logros nuevos, liga y logros
  const A = pg.ach, L = pg.league;
  if (A && A.new.length) html += `<div class="banner ok" style="display:grid;gap:6px"><b>🏅 ¡${A.new.length === 1 ? "Nuevo logro" : "Nuevos logros"}!</b>${A.new.map(x => `<span>${esc(x.title)} · ${esc(x.desc)}</span>`).join("")}</div>`;
  if (L) {
    html += `<section class="pg-sec"><h3>Liga de la semana</h3>
      <p class="note">${L.me.rank ? `Vas <b>${L.me.rank}.º</b> de ${Math.max(L.players, 1)} con <b>${L.me.xp} XP</b>` : "Gana puntos esta semana para entrar en la liga"} · termina en ${L.days_left} ${L.days_left === 1 ? "día" : "días"}.</p>
      ${L.top.length ? `<ol class="pg-league">${L.top.map(p => `<li class="${p.me ? "me" : ""}"><span class="r">${p.rank}</span><span class="n">${esc(p.name)}${p.me ? " (tú)" : ""}</span><b>${p.xp} XP</b></li>`).join("")}</ol>` : ""}
      <label class="inl" for="pgLeagueVis">Aparecer en la liga (solo nombre e inicial) <input type="checkbox" id="pgLeagueVis"${L.visible ? " checked" : ""}></label></section>`;
  }
  if (A) {
    html += `<section class="pg-sec"><h3>Logros · ${A.unlocked} de ${A.total}</h3>
      <div class="pg-ach">${A.achievements.map(x => `<div class="pg-a${x.unlocked_at ? " on" : ""}" title="${esc(x.desc)}"><span class="i">${achIcon(x.icon)}</span><b>${esc(x.title)}</b><small>${esc(x.desc)}</small></div>`).join("")}</div></section>`;
  }

  // Nivel
  if (lv.level) {
    const pct = Math.round((lv.coverage || 0) * 100);
    html += `<section class="pg-sec"><h3>Tu nivel: ${esc(lv.level)} · ${esc(lv.name || "")}</h3>
      <div class="sp-bar"><i style="width:${pct}%"></i></div>
      <p class="note">Has visto ${lv.introduced} de ${lv.total} palabras de ${esc(lv.level)} (${pct}%) y dominas ${lv.mastered}.
      ${lv.next ? (lv.exam_ready ? `<b>Ya puedes hacer el examen para ${esc(lv.next)}.</b>` : `Para el examen de ${esc(lv.next)} necesitas ver ${lv.exam_needed}.`) : "Es el último nivel."}</p></section>`;
  }

  // Vocabulario
  const lvLabels = ["nuevas", ...((cfg.intervals || [1, 3, 7, 15, 30, 60, 120]).map(n => n + "d"))];
  html += `<section class="pg-sec"><h3>Vocabulario</h3>
    <div class="stats"><div class="stat"><b>${v.learned}</b><span>aprendidas</span></div><div class="stat"><b>${v.mastered}</b><span>dominadas</span></div><div class="stat"><b>${v.streak}</b><span>días seguidos</span></div></div>
    <p class="note">Palabras según cada cuánto las repasas: a la derecha, las que ya tienes firmes.</p>
    ${pgBars(v.by_level.map((n, i) => ({ value: n, label: lvLabels[i] || "+", title: n + " palabras" })), 0, "vocab")}</section>`;

  // Hablar
  html += `<section class="pg-sec"><h3>Hablar</h3>
    <div class="stats"><div class="stat"><b>${pgNum(s.total_minutes)}</b><span>min en total</span></div><div class="stat"><b>${s.streak}</b><span>días con la meta</span></div><div class="stat"><b>${pgNum(s.pauses_per_min)}</b><span>pausas largas/min</span></div></div>
    <p class="note">Minutos hablando por semana (la última es la actual):</p>
    ${pgBars(s.weeks.map((w, i) => ({ value: w.minutes, label: i === s.weeks.length - 1 ? "esta" : new Date(w.week + "T12:00").toLocaleDateString("es", { day: "numeric", month: "numeric" }), title: pgNum(w.minutes) + " min" })), 0, "weeks")}
    <div class="pg-trends">
      <div><b>Palabras por minuto</b> ${pgSpark(s.wpm)}<small>${s.wpm.length ? "Última: " + s.wpm[s.wpm.length - 1] + " · nativo: 120–160" : ""}</small></div>
      <div><b>Segundos para arrancar</b> ${pgSpark(s.reaction, true)}<small>${s.reaction.length ? "Última: " + pgNum(s.reaction[s.reaction.length - 1]) + " s · si baja, traduces menos" : ""}</small></div>
    </div></section>`;

  // Pronunciación
  const sounds = d.pronunciation.sounds;
  html += `<section class="pg-sec"><h3>Pronunciación</h3>`;
  html += sounds.length ? `<div class="pg-sounds">${sounds.map(x => `<button type="button" class="pg-snd t-${x.mastered ? "m" : x.tier}" data-pg-lab="${esc(x.phoneme)}"><b>/${esc(x.phoneme)}/</b><small>${x.mastered ? "✅ Dominado" : TIER[x.tier] || ""}</small></button>`).join("")}</div>
      <p class="note">Toca un sonido para practicarlo.</p>` : '<p class="note">Practica fichas con el micrófono y aquí verás tus sonidos difíciles.</p>';
  html += `</section>`;

  // Errores
  const maxCat = Math.max(1, ...m.by_category.map(c => c.count));
  html += `<section class="pg-sec"><h3>Errores al hablar</h3>
    <div class="stats"><div class="stat"><b>${m.pending}</b><span>por superar</span></div><div class="stat"><b>${m.due}</b><span>para repasar hoy</span></div><div class="stat"><b>${m.mastered}</b><span>superados</span></div></div>
    ${m.by_category.length ? `<p class="note">Lo que más se repite:</p><div class="pg-cats">${m.by_category.map(c => `<div class="pg-cat"><span>${esc(c.label)}</span><span class="pg-cbar"><i style="width:${Math.round(c.count / maxCat * 100)}%"></i></span><b>${c.count}</b></div>`).join("")}</div>` : ""}
    ${m.recent.length ? `<p class="note">Los últimos:</p>${m.recent.map(f => `<p class="sp-fix"><s>${esc(f.said)}</s> → <b>${esc(f.correct)}</b></p>`).join("")}` : '<p class="note">Habla en la pestaña Hablar y aquí verás tus errores y su tipo.</p>'}
  </section>`;

  el.innerHTML = html;
  el.querySelectorAll("[data-pg]").forEach(b => b.onclick = () => pgAction(d.todo[+b.dataset.pg]));
  const lv2 = $("pgLeagueVis"); if (lv2) lv2.onchange = async e => { try { pg.league = await api("/league/visibility", { method: "PUT", body: { visible: e.target.checked } }); } catch (er) {} pgRender(); };
  el.querySelectorAll("[data-pg-lab]").forEach(b => b.onclick = () => { unlockAudio(); openLab(b.dataset.pgLab); });
}

function pgAction(t) {
  if (!t) return;
  unlockAudio();
  if (t.action === "cards") return showTab("cards");
  if (t.action === "lab") return openLab(t.arg);
  if (t.action === "exam") return startExam();
  showTab("speak");
  if (t.action === "review") spReviewStart();
  if (t.action === "narrate") spNarrStart(0);
}

// ===== Escalera de español =====
const SP_STEPS = {
  1: ["Con español", "Traducción a la vista y explicaciones en español."],
  2: ["Primero inglés", "Definición en inglés; el español solo si lo pides."],
  3: ["Interfaz en inglés", "La app en inglés y español con límite diario."],
  4: ["Solo inglés", "Sin español: todo se explica en inglés."],
};
function spanishSection(sp) {
  const dots = [1, 2, 3, 4].map(n => `<span class="sp-step${n <= sp.step ? " on" : ""}${n === sp.step ? " cur" : ""}" title="${esc(SP_STEPS[n][0])}">${n}</span>`).join("");
  const opts = `<option value="auto"${sp.auto ? " selected" : ""}>Automático (ahora: ${(sp.auto_step ?? sp.step) > sp.base ? "escalón " + sp.auto_step + ", subiste por usar poco español" : "escalón " + sp.base + ", según tu nivel"})</option>`
    + [1, 2, 3, 4].map(n => `<option value="${n}"${!sp.auto && sp.step === n ? " selected" : ""}>${n} · ${esc(SP_STEPS[n][0])}</option>`).join("");
  return `<section class="pg-sec"><h3>Tu español</h3>
    <div class="sp-ladder">${dots}<b>${esc(SP_STEPS[sp.step][0])}</b></div>
    <p class="note">${esc(SP_STEPS[sp.step][1])} Pensar en inglés es dejar de pasar por el español: cada escalón te quita un poco.</p>
    <div class="pg-sp">
      <div><b>${sp.today}${sp.limit != null ? " / " + sp.limit : ""}</b><span>veces hoy</span></div>
      <div><b>${sp.week}</b><span>esta semana</span></div>
      <div><b>${sp.streak}</b><span>${sp.streak === 1 ? "día" : "días"} sin español</span></div>
    </div>
    ${sp.translating ? `<p class="warnbox">Tardas ${String(sp.reaction).replace(".", ",")} s en empezar a hablar: señal de que traduces mentalmente. Prueba «Respuesta rápida» en Hablar.</p>` : sp.reaction != null ? `<p class="note">Empiezas a hablar en ${String(sp.reaction).replace(".", ",")} s de media. Menos de 2,5 s es buena señal.</p>` : ""}
    <label class="inl" for="spStepSel">Escalón <select id="spStepSel" style="width:auto;max-width:240px">${opts}</select></label>
  </section>`;
}
document.addEventListener("change", async e => {
  if (e.target.id !== "spStepSel") return;
  const v = e.target.value;
  try {
    const sp = await api("/spanish", { method: "PUT", body: { step: v === "auto" ? null : Number(v) } });
    if (profile) profile.spanish = sp;
    if (typeof applyUiLang === "function") applyUiLang();
    pgOpen();
  } catch (err) { alert(err.message); }
});
