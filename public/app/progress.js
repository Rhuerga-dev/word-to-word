/* Word to Word · Panel de progreso: qué hacer hoy, nivel, vocabulario, hablar, pronunciación y errores. */
"use strict";

const pg = { data: null, error: "" };
const pgNum = n => String(n ?? "—").replace(".", ",");

async function pgOpen() {
  const el = $("progressBody"); if (!el) return;
  if (!pg.data) el.innerHTML = '<p class="note">Cargando tu progreso…</p>';
  try { pg.data = await api("/progress"); pg.error = ""; } catch (e) { pg.error = e.message; }
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
