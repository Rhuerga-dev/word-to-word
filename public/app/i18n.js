/* Escalera de español: desde el escalón 3 la interfaz va en inglés.
   Traduce los textos de la página (y las instrucciones habladas) sin tocar el resto del código:
   1) texto exacto; 2) con números, niveles (B1) y sonidos (/θ/) como variables; 3) frases largas dentro de otros textos.
   Lo que no está en el diccionario (palabras del alumno, ejemplos en inglés) se queda como está. */
(function () {
  // El diccionario vive en el servidor (lang/en.json, como en CuPay) y se guarda en el navegador.
  let EN = {}, FRAGS = [], version = null;
  function setDict(d, v) {
    EN = d || {}; version = v || null;
    // Frases largas para reemplazar dentro de textos mezclados (sin variables), las más largas primero.
    FRAGS = Object.keys(EN).filter(k => k.length >= 12 && !/\{[npl0-9]\}/.test(k)).sort((a, b) => b.length - a.length);
  }
  try { const c = JSON.parse(localStorage.getItem("wtw_i18n_en") || "null"); if (c && c.strings) setDict(c.strings, c.version); } catch (e) {}
  /** Descarga el diccionario si cambió; si la interfaz ya va en inglés, la vuelve a traducir. */
  async function load() {
    try {
      const r = await fetch("/api/i18n/en", { headers: { Accept: "application/json" } });
      if (!r.ok) return;
      const d = await r.json();
      if (d.version === version) return;
      setDict(d.strings, d.version);
      try { localStorage.setItem("wtw_i18n_en", JSON.stringify({ version: d.version, strings: d.strings })); } catch (e) {}
      if (on) walk(document.body);
    } catch (e) { /* sin conexión: se usa lo guardado */ }
  }

  // Fechas cortas en español (vie 13, 11 nov, miércoles, 11 nov).
  const WD = { lun: "Mon", mar: "Tue", "mié": "Wed", jue: "Thu", vie: "Fri", "sáb": "Sat", dom: "Sun" };
  const WDL = { lunes: "Monday", martes: "Tuesday", "miércoles": "Wednesday", jueves: "Thursday", viernes: "Friday", "sábado": "Saturday", domingo: "Sunday" };
  const MO = { ene: "Jan", feb: "Feb", mar: "Mar", abr: "Apr", may: "May", jun: "Jun", jul: "Jul", ago: "Aug", sept: "Sep", sep: "Sep", oct: "Oct", nov: "Nov", dic: "Dec" };

  const TOKEN = /\/[^/\s]{1,4}\/|\b[ABC][12]\b|\d+(?:[.,]\d+)?/g;
  const kindOf = m => m[0] === "/" ? "p" : /^[ABC][12]$/.test(m) ? "l" : "n";

  function fill(tpl, vals) {
    const q = { n: [], p: [], l: [] };
    vals.forEach(v => q[kindOf(v)].push(v));
    return tpl.replace(/\{([npl])\}/g, (_, k) => q[k].length ? q[k].shift() : "");
  }
  function core(t) {
    if (EN[t] != null) return EN[t];
    const vals = [], key = t.replace(TOKEN, m => { vals.push(m); return "{" + kindOf(m) + "}"; });
    if (vals.length && EN[key] != null) return fill(EN[key], vals);
    let m;
    if ((m = t.match(/^(\d+) de (\d+)( · .*)?$/))) return m[1] + " of " + m[2] + (m[3] || "");
    if ((m = t.match(/^(lun|mar|mié|jue|vie|sáb|dom) (\d+)$/))) return WD[m[1]] + " " + m[2];
    if ((m = t.match(/^(?:(lunes|martes|miércoles|jueves|viernes|sábado|domingo), )?(\d+) (ene|feb|mar|abr|may|jun|jul|ago|sept?|oct|nov|dic)\.?$/))) return (m[1] ? WDL[m[1]] + ", " : "") + MO[m[3]] + " " + m[2];
    return null;
  }
  /** Traduce un texto de la interfaz; null si no lo conoce. */
  function tr(text, strict) {
    const t = String(text).replace(/\s+/g, " ").trim();
    if (!t) return null;
    let out = core(t);
    if (out != null) return out;
    // Emoji o símbolos delante/detrás: se traduce el centro.
    const m = t.match(/^([^\p{L}¿¡“"(]*)(.*?)([^\p{L}.!?…)”"]*)$/u);
    if (m && (m[1] || m[3])) { const c = core(m[2].trim()); if (c != null) return m[1] + c + m[3]; }
    // Partes separadas por " · ": se traduce cada una.
    if (t.includes(" · ")) {
      let any = false;
      const parts = t.split(" · ").map(p => { const x = tr(p, true); if (x != null) { any = true; return x; } return p; });
      if (any) return parts.join(" · ");
    }
    if (strict) return null;
    // Frases conocidas dentro del texto.
    let s = t, hit = false;
    for (const f of FRAGS) if (s.includes(f)) { s = s.split(f).join(EN[f]); hit = true; }
    return hit ? s : null;
  }

  // ----- Aplicar a la página -----
  const ORIG = new WeakMap(), MINE = new WeakMap(), ATTRS = ["placeholder", "aria-label", "title"];
  let on = false, obs = null, busy = false;
  const skip = el => !el || /^(SCRIPT|STYLE|TEXTAREA|INPUT)$/.test(el.tagName) || el.closest("[data-no-i18n],.msg,.sp-topic,.word,.fw,.ex,.fex,.def,.sess-word,.sess-ex,.sess-def");
  function doText(n) {
    if (skip(n.parentElement)) return;
    const orig = ORIG.has(n) ? ORIG.get(n) : n.nodeValue;
    if (!ORIG.has(n)) ORIG.set(n, orig);
    const out = tr(orig);
    if (out != null) { const lead = orig.match(/^\s*/)[0], trail = orig.match(/\s*$/)[0]; const v = lead + out + trail; if (n.nodeValue !== v) { n.nodeValue = v; MINE.set(n, v); } }
  }
  function doEl(el) {
    for (const a of ATTRS) {
      if (!el.hasAttribute(a)) continue;
      const key = "data-i18n-" + a;
      const orig = el.getAttribute(key) ?? el.getAttribute(a);
      if (!el.hasAttribute(key)) el.setAttribute(key, orig);
      const out = tr(orig); if (out != null && el.getAttribute(a) !== out) { el.setAttribute(a, out); const m = MINE.get(el) || {}; m[a] = out; MINE.set(el, m); }
    }
  }
  function walk(root) {
    if (root.nodeType === 3) return doText(root);
    if (root.nodeType !== 1 || skip(root)) return;
    doEl(root);
    const w = document.createTreeWalker(root, NodeFilter.SHOW_TEXT | NodeFilter.SHOW_ELEMENT);
    let n; while ((n = w.nextNode())) n.nodeType === 3 ? doText(n) : doEl(n);
  }
  function restore() {
    const w = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT | NodeFilter.SHOW_ELEMENT);
    let n; while ((n = w.nextNode())) {
      if (n.nodeType === 3) { if (ORIG.has(n)) { n.nodeValue = ORIG.get(n); ORIG.delete(n); } }
      else for (const a of ATTRS) { const k = "data-i18n-" + a; if (n.hasAttribute(k)) { n.setAttribute(a, n.getAttribute(k)); n.removeAttribute(k); } }
    }
  }
  function setOn(v) {
    if (v === on) return;
    on = v;
    document.documentElement.lang = v ? "en" : "es";
    if (v) {
      walk(document.body);
      obs = new MutationObserver(list => {
        if (busy) return; busy = true;
        try {
          for (const r of list) {
            // El código de la app cambió un texto: ese pasa a ser el original.
            if (r.type === "characterData") { if (r.target.nodeValue === MINE.get(r.target)) continue; ORIG.set(r.target, r.target.nodeValue); doText(r.target); }
            else if (r.type === "attributes") { if (r.target.getAttribute(r.attributeName) === (MINE.get(r.target) || {})[r.attributeName]) continue; const k = "data-i18n-" + r.attributeName; r.target.setAttribute(k, r.target.getAttribute(r.attributeName)); doEl(r.target); }
            else r.addedNodes.forEach(walk);
          }
        } finally { busy = false; }
      });
      obs.observe(document.body, { subtree: true, childList: true, characterData: true, attributes: true, attributeFilter: ATTRS });
    } else {
      if (obs) { obs.takeRecords(); obs.disconnect(); } obs = null;
      restore();
    }
  }

  load();
  window.I18N_EN = { tr, setOn, load, isOn: () => on, dict: () => EN };
})();

/** Interfaz en inglés desde el escalón 3 (lo decide el servidor en profile.spanish.ui). */
function uiEnglish() { return !!(typeof profile !== "undefined" && profile && profile.spanish && profile.spanish.ui === "en"); }
function applyUiLang() { window.I18N_EN.setOn(uiEnglish()); }
/** Instrucciones habladas: si la interfaz va en inglés y la frase está en el diccionario, se dice en inglés. */
function uiSpeech(text, lang) {
  if (!uiEnglish() || !String(lang || "").startsWith("es")) return [text, lang];
  const t = window.I18N_EN.tr(text, true);
  return t != null ? [t, String(lang).length > 2 ? "en-US" : "en"] : [text, lang];
}
