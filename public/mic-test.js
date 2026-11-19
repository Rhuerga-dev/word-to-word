// Prueba de micrófono (/prueba-micro). Graba 3 s de silencio y 7 s de voz y los analiza aquí, en el navegador.
// No hay ninguna petición al servidor: la voz no sale del teléfono.
(function () {
  'use strict';

  var QUIET = 3, TALK = 7; // segundos de cada parte

  // ---------- Análisis (cuentas puras: sirven igual fuera del navegador) ----------

  function db(power) { return 10 * Math.log10(Math.max(power, 1e-12)); }

  /** Potencia media de cada trozo de [ms] milisegundos. */
  function framePowers(x, rate, ms) {
    var n = Math.max(1, Math.round(rate * ms / 1000)), out = [];
    for (var i = 0; i + n <= x.length; i += n) {
      var s = 0;
      for (var j = i; j < i + n; j++) s += x[j] * x[j];
      out.push(s / n);
    }
    return out;
  }

  function percentile(values, p) {
    if (!values.length) return 0;
    var v = values.slice().sort(function (a, b) { return a - b; });
    return v[Math.min(v.length - 1, Math.max(0, Math.round(p * (v.length - 1))))];
  }

  /** Transformada de Fourier (FFT) de tamaño potencia de 2, en el sitio. */
  function fft(re, im) {
    var n = re.length;
    for (var i = 1, j = 0; i < n; i++) {
      var bit = n >> 1;
      for (; j & bit; bit >>= 1) j ^= bit;
      j ^= bit;
      if (i < j) { var t = re[i]; re[i] = re[j]; re[j] = t; t = im[i]; im[i] = im[j]; im[j] = t; }
    }
    for (var len = 2; len <= n; len <<= 1) {
      var ang = -2 * Math.PI / len, wr = Math.cos(ang), wi = Math.sin(ang);
      for (var s = 0; s < n; s += len) {
        var cr = 1, ci = 0;
        for (var k = 0; k < len / 2; k++) {
          var a = s + k, b = a + len / 2;
          var xr = re[b] * cr - im[b] * ci, xi = re[b] * ci + im[b] * cr;
          re[b] = re[a] - xr; im[b] = im[a] - xi; re[a] += xr; im[a] += xi;
          var nr = cr * wr - ci * wi; ci = cr * wi + ci * wr; cr = nr;
        }
      }
    }
  }

  /** Cuánta energía hay en cada banda de 250 Hz, de media, en los trozos elegidos por [keep]. */
  function bands(x, rate, keep) {
    var N = 2048, width = 250, count = Math.floor(rate / 2 / width), sum = new Float64Array(count), used = 0;
    var re = new Float64Array(N), im = new Float64Array(N);
    for (var start = 0; start + N <= x.length; start += N) {
      var p = 0;
      for (var i = 0; i < N; i++) p += x[start + i] * x[start + i];
      if (!keep(p / N)) continue;
      for (i = 0; i < N; i++) { re[i] = x[start + i] * (0.5 - 0.5 * Math.cos(2 * Math.PI * i / (N - 1))); im[i] = 0; }
      fft(re, im);
      for (var k = 1; k < N / 2; k++) {
        var band = Math.floor(k * rate / N / width);
        if (band < count) sum[band] += re[k] * re[k] + im[k] * im[k];
      }
      used++;
    }
    for (var b = 0; b < count; b++) sum[b] = used ? sum[b] / used : 0;
    return sum;
  }

  /**
   * Mide una grabación: [noise] = la parte en silencio, [speech] = la parte hablando, [rate] = muestras por segundo.
   * Devuelve los números y una nota: 'good' (bueno), 'fair' (regular) o 'bad' (malo), con sus motivos.
   */
  function analyze(noise, speech, rate) {
    var noiseDb = db(percentile(framePowers(noise, rate, 50), 0.5));
    var frames = framePowers(speech, rate, 30);
    var voicePower = percentile(frames, 0.9);
    var voiceDb = db(voicePower), snr = voiceDb - noiseDb;

    var clipped = 0;
    for (var i = 0; i < speech.length; i++) if (Math.abs(speech[i]) >= 0.98) clipped++;
    var clipping = speech.length ? 100 * clipped / speech.length : 0;

    // Cortes: tramos de 30 ms o más de silencio «digital» (ni ruido), en mitad de la parte hablada.
    var gaps = 0, run = 0, need = Math.round(rate * 0.03);
    for (i = 0; i < speech.length; i++) {
      if (Math.abs(speech[i]) < 1e-5) { run++; if (run === need) gaps++; } else run = 0;
    }

    // Agudos: la frecuencia más alta donde la voz se distingue del ruido (y no es un resto insignificante).
    var loud = voicePower / 10;
    var v = bands(speech, rate, function (p) { return p >= loud; });
    var q = bands(noise, rate, function () { return true; });
    var top = 0, peak = 0;
    for (var b = 0; b < v.length; b++) peak = Math.max(peak, v[b]);
    for (b = 0; b < v.length; b++) {
      if (v[b] > q[b] * 10 && v[b] > peak / 3e4) top = (b + 1) * 250;
    }

    var grade = 'good', why = [];
    function worse(g, text) { if (g === 'bad' || grade === 'good') grade = g; why.push(text); }
    if (snr < 6) {
      return { grade: 'bad', why: ['No se oyó tu voz. Revisa que el micrófono elegido sea el correcto y habla durante la prueba.'], snr: snr, noiseDb: noiseDb, voiceDb: voiceDb, top: top, clipping: clipping, gaps: gaps, rate: rate };
    }
    if (snr < 12) worse('bad', 'Hay demasiado ruido: tu voz casi no sobresale.');
    else if (snr < 20) worse('fair', 'Hay bastante ruido de fondo.');
    if (voiceDb < -45) worse('fair', 'Tu voz llega muy bajita.');
    if (clipping > 1) worse('bad', 'La voz se distorsiona (llega demasiado fuerte).');
    else if (clipping > 0.1) worse('fair', 'La voz se distorsiona un poco.');
    // Algunos micrófonos apagan del todo el sonido entre palabras, así que esto solo baja la nota a «regular».
    if (gaps > 5) worse('fair', 'El sonido parece cortarse a ratos: escucha la grabación para confirmarlo.');
    if (top < 3000) worse('bad', 'Suena muy apagado: faltan los agudos y se confunden las consonantes.');
    else if (top < 4500) worse('fair', 'Suena como una llamada de teléfono: sin agudos, sonidos como «s», «f» y «th» se confunden más.');
    if (!why.length) why.push('La voz se oye clara, con poco ruido y con agudos.');
    return { grade: grade, why: why, snr: snr, noiseDb: noiseDb, voiceDb: voiceDb, top: top, clipping: clipping, gaps: gaps, rate: rate };
  }

  /** La grabación como archivo WAV (para volver a escucharla). */
  function wav(x, rate) {
    var buf = new ArrayBuffer(44 + x.length * 2), d = new DataView(buf);
    function str(o, s) { for (var i = 0; i < s.length; i++) d.setUint8(o + i, s.charCodeAt(i)); }
    str(0, 'RIFF'); d.setUint32(4, 36 + x.length * 2, true); str(8, 'WAVE'); str(12, 'fmt ');
    d.setUint32(16, 16, true); d.setUint16(20, 1, true); d.setUint16(22, 1, true);
    d.setUint32(24, rate, true); d.setUint32(28, rate * 2, true); d.setUint16(32, 2, true); d.setUint16(34, 16, true);
    str(36, 'data'); d.setUint32(40, x.length * 2, true);
    for (var i = 0; i < x.length; i++) d.setInt16(44 + i * 2, Math.max(-1, Math.min(1, x[i])) * 32767, true);
    return buf;
  }

  var api = { analyze: analyze, wav: wav };
  if (typeof module !== 'undefined' && module.exports) { module.exports = api; return; } // para probar las cuentas
  if (typeof document === 'undefined') return;

  // ---------- La página ----------

  var $ = function (id) { return document.getElementById(id); };
  var GRADES = { good: 'Bueno', fair: 'Regular', bad: 'Malo' };
  var KEY = 'w2w-mic-tests';
  var stream = null, ctx = null, node = null, playUrl = null;

  function show(id, on) { $(id).hidden = !on; }
  function fail(text) { $('error').textContent = text; show('error', true); show('setup', true); show('run', false); }

  function load() { try { return JSON.parse(localStorage.getItem(KEY) || '[]'); } catch (e) { return []; } }
  function save(list) { try { localStorage.setItem(KEY, JSON.stringify(list.slice(-12))); } catch (e) { /* sin memoria: no pasa nada */ } }

  function stop() {
    if (node) { node.disconnect(); node.onaudioprocess = null; node = null; }
    if (stream) { stream.getTracks().forEach(function (t) { t.stop(); }); stream = null; }
    if (ctx) { ctx.close(); ctx = null; }
  }

  /** Rellena la lista de micrófonos (los nombres solo se ven después de dar permiso). */
  function listDevices(current) {
    if (!navigator.mediaDevices.enumerateDevices) return Promise.resolve();
    return navigator.mediaDevices.enumerateDevices().then(function (all) {
      var mics = all.filter(function (d) { return d.kind === 'audioinput' && d.label; });
      var select = $('device');
      select.textContent = '';
      mics.forEach(function (m) {
        var o = document.createElement('option');
        o.value = m.deviceId; o.textContent = m.label; o.selected = m.deviceId === current;
        select.appendChild(o);
      });
      show('pick', mics.length > 1);
    });
  }

  function start() {
    show('error', false);
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) return fail('Este navegador no deja usar el micrófono. Prueba con Safari o Chrome.');
    var chosen = $('pick').hidden ? null : $('device').value;
    // Sin filtros del navegador, para medir el micrófono tal como es.
    var audio = { echoCancellation: false, noiseSuppression: false, autoGainControl: false };
    if (chosen) audio.deviceId = { exact: chosen };
    var AC = window.AudioContext || window.webkitAudioContext;
    ctx = new AC(); // se crea en el toque, o el iPhone no lo deja sonar

    navigator.mediaDevices.getUserMedia({ audio: audio }).then(function (s) {
      stream = s;
      var track = s.getAudioTracks()[0], id = track.getSettings ? track.getSettings().deviceId : null;
      $('using').textContent = track.label || 'desconocido';
      listDevices(id);
      show('setup', false); show('result', false); show('run', true);

      var chunks = [], total = 0, rate = ctx.sampleRate, need = (QUIET + TALK) * rate, split = QUIET * rate;
      var began = false;
      node = ctx.createScriptProcessor(4096, 1, 1);
      node.onaudioprocess = function (e) {
        var x = e.inputBuffer.getChannelData(0);
        if (total >= need) return;
        chunks.push(new Float32Array(x)); total += x.length;
        var p = 0;
        for (var i = 0; i < x.length; i++) p += x[i] * x[i];
        $('level').style.width = Math.max(0, Math.min(100, (db(p / x.length) + 70) * 1.6)) + '%';
        var talking = total >= split;
        if (talking && !began) { began = true; $('step').textContent = 'Ahora lee esto en voz alta'; show('say', true); }
        $('count').textContent = String(Math.max(0, Math.ceil(((talking ? need : split) - total) / rate)));
        if (total >= need) finish(chunks, total, rate, split, track.label || 'desconocido');
      };
      $('step').textContent = 'Quédate en silencio';
      show('say', false);
      $('count').textContent = String(QUIET);
      ctx.createMediaStreamSource(s).connect(node);
      node.connect(ctx.destination); // hace falta para que el nodo trabaje; no suena nada (no copia la entrada)
      if (ctx.state === 'suspended') ctx.resume();
    }).catch(function (e) {
      stop();
      fail(e && e.name === 'NotAllowedError' ? 'No diste permiso para usar el micrófono. Actívalo en los ajustes del navegador y vuelve a intentarlo.'
        : e && e.name === 'NotFoundError' ? 'No se encontró ningún micrófono.' : 'No se pudo abrir el micrófono. Vuelve a intentarlo.');
    });
  }

  function finish(chunks, total, rate, split, mic) {
    stop();
    var all = new Float32Array(total), at = 0;
    chunks.forEach(function (c) { all.set(c, at); at += c.length; });
    // Se descarta el primer medio segundo: al abrirse, muchos micrófonos hacen un «clic».
    var r = analyze(all.subarray(Math.round(rate * 0.5), split), all.subarray(split), rate);
    r.label = $('label').value.trim() || 'Sin nombre';
    r.mic = mic;
    r.when = new Date().toISOString();

    if (playUrl) URL.revokeObjectURL(playUrl);
    playUrl = URL.createObjectURL(new Blob([wav(all, rate)], { type: 'audio/wav' }));
    $('play').src = playUrl;

    $('verdict').textContent = GRADES[r.grade] + ' para practicar hablando';
    $('verdict').className = r.grade;
    $('why').textContent = r.why.join(' ');
    var rows = [
      ['Voz frente al ruido', r.snr.toFixed(0) + ' dB (bueno: 20 o más)'],
      ['Agudos hasta', (r.top / 1000).toFixed(1).replace('.', ',') + ' kHz (bueno: 4,5 o más)'],
      ['Ruido de fondo', r.noiseDb.toFixed(0) + ' dB'],
      ['Volumen de tu voz', r.voiceDb.toFixed(0) + ' dB'],
      ['Distorsión', r.clipping.toFixed(2).replace('.', ',') + ' %'],
      ['Cortes', String(r.gaps)],
      ['Micrófono', r.mic],
    ];
    var body = $('numbers');
    body.textContent = '';
    rows.forEach(function (row) {
      var tr = document.createElement('tr'), th = document.createElement('th'), td = document.createElement('td');
      th.textContent = row[0]; td.textContent = row[1]; tr.appendChild(th); tr.appendChild(td); body.appendChild(tr);
    });
    show('run', false); show('result', true);

    var list = load();
    list.push({ label: r.label, grade: r.grade, snr: r.snr, top: r.top, noiseDb: r.noiseDb, voiceDb: r.voiceDb, clipping: r.clipping, gaps: r.gaps, mic: r.mic, when: r.when, rate: r.rate });
    save(list);
    history(list);
  }

  function summary(list) {
    return list.map(function (t) {
      return [t.label, GRADES[t.grade] || t.grade, 'voz/ruido ' + Number(t.snr).toFixed(0) + ' dB', 'agudos ' + (t.top / 1000).toFixed(1) + ' kHz',
        'ruido ' + Number(t.noiseDb).toFixed(0) + ' dB', 'voz ' + Number(t.voiceDb).toFixed(0) + ' dB', 'distorsión ' + Number(t.clipping).toFixed(2) + ' %',
        'cortes ' + t.gaps, 'mic: ' + t.mic, t.rate + ' Hz', String(t.when).slice(0, 16)].join(' | ');
    }).join('\n');
  }

  function history(list) {
    var body = $('rows');
    body.textContent = '';
    list.forEach(function (t) {
      var tr = document.createElement('tr');
      [t.label, GRADES[t.grade] || t.grade, Number(t.snr).toFixed(0) + ' dB', (t.top / 1000).toFixed(1).replace('.', ',') + ' kHz', t.mic].forEach(function (text, i) {
        var td = document.createElement('td');
        td.textContent = text;
        if (i === 1) td.className = t.grade === 'good' || t.grade === 'fair' || t.grade === 'bad' ? t.grade : '';
        tr.appendChild(td);
      });
      body.appendChild(tr);
    });
    show('history', list.length > 0);
    show('text', false); show('copied', false);
  }

  $('start').addEventListener('click', start);
  $('again').addEventListener('click', function () { show('result', false); show('setup', true); $('label').focus(); });
  $('clear').addEventListener('click', function () { save([]); history([]); });
  $('copy').addEventListener('click', function () {
    var text = 'Prueba de micrófono W2W\n' + summary(load());
    var done = function () { show('copied', true); };
    var manual = function () { $('text').value = text; show('text', true); $('text').focus(); $('text').select(); };
    if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(text).then(done, manual); else manual();
  });
  history(load());
})();
