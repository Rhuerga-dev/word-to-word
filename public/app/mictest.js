/* Prueba del micrófono (Ajustes): mide el ruido de fondo, el volumen de tu voz y si el servidor te entiende.
   Usa el mismo micrófono y los mismos ajustes que las prácticas (getMic), así el resultado es el real. */
(function () {
  const SENTENCE = "I need the invoice before Friday.";
  const dB = v => v > 0 ? 20 * Math.log10(v) : -100;
  let running = false;

  function box() { return document.getElementById("micTestOut"); }
  function show(html) { const b = box(); b.hidden = false; b.innerHTML = html; }

  /** Elige el micrófono del propio teléfono (no el Bluetooth) y repite la prueba. */
  async function switchToPhone() {
    const mics = await listMics();
    const phone = mics.find(m => /iphone|built-?in|integrad|interno|internal/i.test(m.label))
      || mics.find(m => m.label && !/airpods|bluetooth|headset|beats|buds|hands-?free/i.test(m.label));
    if (!phone) { show(`<p class="mt-bad">❌ No encontré otro micrófono en este teléfono.</p>`); return; }
    mic.pref = phone.deviceId;
    try { localStorage.setItem("wtw_mic", mic.pref); } catch (e) {}
    releaseMic();
    if (typeof renderMicSelect === "function") renderMicSelect();
    run(true);
  }

  async function run(switched) {
    if (running) return;
    running = true;
    const btn = document.getElementById("micTest");
    btn.disabled = true;
    let ctx, src, proc, stream;
    try {
      stream = await getMic();
      ctx = new (window.AudioContext || window.webkitAudioContext)();
      if (ctx.state === "suspended") await ctx.resume(); // iPhone: dentro del toque
      src = ctx.createMediaStreamSource(stream);
      proc = ctx.createScriptProcessor(4096, 1, 1);
      const track = stream.getAudioTracks()[0], label = (track && track.label) || "";
      const frames = []; // {rms, peak, t, phase}
      const chunks = []; let phase = "noise", t0 = ctx.currentTime, heardAt = 0, quietFor = 0, stopAt = 0;
      src.connect(proc); proc.connect(ctx.destination);

      show(`<p class="mt-step">🤫 Quédate en silencio un momento…</p><div class="mt-meter"><span id="mtLevel"></span></div>`);
      const done = new Promise(resolve => {
        proc.onaudioprocess = e => {
          const d = new Float32Array(e.inputBuffer.getChannelData(0));
          let s = 0, peak = 0; for (let i = 0; i < d.length; i++) { s += d[i] * d[i]; const a = Math.abs(d[i]); if (a > peak) peak = a; }
          const rms = Math.sqrt(s / d.length), t = ctx.currentTime - t0, dur = d.length / ctx.sampleRate;
          frames.push({ rms, peak, phase });
          if (phase === "speak") chunks.push(d);
          const lvl = document.getElementById("mtLevel");
          if (lvl) lvl.style.width = Math.max(2, Math.min(100, (dB(rms) + 60) / 60 * 100)) + "%";
          if (phase === "noise" && t > 1.5) {
            phase = "speak";
            show(`<p class="mt-step">🎙️ Ahora di en voz alta, como hablas normalmente:</p><p class="mt-say">“${SENTENCE}”</p><div class="mt-meter"><span id="mtLevel"></span></div>`);
          } else if (phase === "speak") {
            const floor = noiseRms(frames);
            const voice = rms > Math.max(0.01, floor * 4);
            if (voice) { heardAt = heardAt || t; quietFor = 0; } else if (heardAt) quietFor += dur;
            // Termina tras 1,2 s de silencio después de hablar, o a los 8 s.
            if ((heardAt && quietFor > 1.2) || t > 9.5) { stopAt = t; resolve(); }
          }
        };
      });
      await done;
      proc.onaudioprocess = null;
      const rate = ctx.sampleRate;
      try { proc.disconnect(); src.disconnect(); } catch (e) {}
      if (!mic.keep) releaseMic();
      ctx.close();

      const wav = encodeWav(downsample(flatten(chunks), rate, 16000), 16000);
      const a = analyze(frames, rate, label);
      a.switched = switched === true;
      if (typeof renderMicSelect === "function") renderMicSelect(); // ahora ya se ven los nombres
      show(`<p class="mt-step">Analizando…</p>`);
      a.heard = await understood(wav);
      render(a, wav);
    } catch (e) {
      show(`<p class="mt-bad">❌ ${esc(/denied|allowed|permission/i.test(e.message || e.name) ? "Permite el micrófono en el navegador." : e.message || "No se pudo usar el micrófono.")}</p>`);
      try { ctx && ctx.close(); } catch (er) {}
    } finally {
      running = false;
      btn.disabled = false;
    }
  }

  function noiseRms(frames) {
    const n = frames.filter(f => f.phase === "noise").map(f => f.rms).sort((a, b) => a - b);
    return n.length ? n[Math.floor(n.length / 2)] : 0.001;
  }

  function analyze(frames, rate, label) {
    const floor = noiseRms(frames);
    const sp = frames.filter(f => f.phase === "speak");
    const voiced = sp.filter(f => f.rms > Math.max(0.01, floor * 4));
    const vRms = voiced.length ? Math.sqrt(voiced.reduce((s, f) => s + f.rms * f.rms, 0) / voiced.length) : 0;
    const clipped = sp.filter(f => f.peak > 0.98).length;
    return {
      label, rate,
      bluetooth: /airpods|bluetooth|headset|beats|buds|hands-?free/i.test(label),
      noiseDb: Math.round(dB(floor)),
      voiceDb: Math.round(dB(vRms)),
      snr: Math.round(dB(vRms) - dB(floor)),
      clipping: voiced.length ? clipped / voiced.length : 0,
      spoke: voiced.length > 2,
    };
  }

  /** El servidor transcribe la frase: % de palabras que entendió. null si no hay transcripción. */
  async function understood(wav) {
    if (!cfg.pronunciation) return null;
    try {
      const fd = new FormData(); fd.append("audio", wav, "voz.wav"); fd.append("lang", "en");
      const r = await api("/speech/transcribe", { method: "POST", body: fd });
      return { text: r.text || "", pct: compare(SENTENCE, r.text || "").pct };
    } catch (e) { return null; }
  }

  function row(ok, title, detail) {
    const icon = ok === 2 ? "✅" : ok === 1 ? "⚠️" : "❌";
    return `<li class="mt-row"><span>${icon}</span><span><b>${esc(title)}</b><br><span class="note">${esc(detail)}</span></span></li>`;
  }

  function render(a, wav) {
    if (!a.spoke) {
      show(`<p class="mt-bad">❌ No te oí. Revisa que el micrófono no esté tapado y que hayas permitido el micrófono, y prueba otra vez.</p>${a.label ? `<p class="note">Micrófono: ${esc(a.label)}</p>` : ""}`);
      return;
    }
    const tips = [];
    const vol = a.clipping > 0.05 ? 1 : a.voiceDb >= -30 ? 2 : a.voiceDb >= -40 ? 1 : 0;
    if (a.clipping > 0.05) tips.push("Tu voz satura: aleja un poco el teléfono de la boca.");
    else if (vol < 2) tips.push("Se te oye bajo: acerca el micrófono (unos 15–20 cm) o habla un poco más fuerte.");
    const noise = a.snr >= 25 ? 2 : a.snr >= 15 ? 1 : 0;
    if (noise < 2) tips.push("Hay ruido de fondo: busca un lugar más silencioso o apaga la tele, el ventilador o la música.");
    let rows = row(vol, "Volumen de tu voz", vol === 2 ? "Bien: se te oye claro." : a.clipping > 0.05 ? "Demasiado alto: se distorsiona." : "Bajo.")
      + row(noise, "Ruido de fondo", noise === 2 ? "Poco ruido: tu voz destaca bien." : noise === 1 ? "Algo de ruido: a veces puede confundirte con él." : "Mucho ruido: tu voz casi no destaca.");
    if (a.heard) {
      const h = a.heard.pct >= 80 ? 2 : a.heard.pct >= 50 ? 1 : 0;
      rows += row(h, `Te entiende: ${a.heard.pct}%`, a.heard.text ? `Entendí: “${a.heard.text}”` : "No entendí ninguna palabra.");
      if (h < 2 && vol === 2 && noise === 2) tips.push("El audio está bien: habla un poco más despacio y separando las palabras.");
    }
    if (a.bluetooth) tips.push(a.switched
      ? "El iPhone siguió usando el micrófono de tus audífonos aunque elegí el del iPhone. Para practicar con buena calidad, quítate los audífonos o usa la app W2W."
      : "Estás usando el micrófono de tus audífonos Bluetooth: suena peor y hace que la voz de la app baje de calidad. Elige el micrófono del iPhone arriba y prueba otra vez.");
    const all = vol + noise + (a.heard ? (a.heard.pct >= 80 ? 2 : a.heard.pct >= 50 ? 1 : 0) : 2);
    const verdict = all >= 6 && !a.bluetooth ? "✅ Tu micrófono está listo para practicar." : all >= 4 ? "⚠️ Funciona, pero se puede mejorar:" : "❌ Así te va a costar que la app te entienda:";
    const url = URL.createObjectURL(wav);
    show(`<p class="mt-verdict">${esc(verdict)}</p><ul class="mt-list">${rows}</ul>`
      + (tips.length ? `<ul class="mt-tips">${tips.map(t => `<li>${esc(t)}</li>`).join("")}</ul>` : "")
      + `<p class="note">Micrófono: ${esc(a.label || "automático")} · voz ${a.voiceDb} dB · ruido ${a.noiseDb} dB</p>`
      + `<p class="mt-step">Escúchate:</p><audio controls src="${url}" style="width:100%"></audio>`
      + `<div class="row">${a.bluetooth && !a.switched ? '<button type="button" class="primary" id="micUsePhone">Usar el micrófono del iPhone y probar otra vez</button>' : ""}<button type="button" id="micTestAgain">Probar otra vez</button></div>`);
    document.getElementById("micTestAgain").onclick = () => run();
    const usePhone = document.getElementById("micUsePhone");
    if (usePhone) usePhone.onclick = () => switchToPhone();
  }

  const b = document.getElementById("micTest");
  if (b) b.onclick = () => run();
})();
