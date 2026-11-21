// Brainy, la mascota de W2W, dibujada con código en un <canvas> (sin imágenes).
// Es una copia fiel del dibujo de la app Flutter (mobile/lib/features/pet/presentation/pet_figure.dart,
// pet_cloud.dart y la animación de pet_birth.dart): mismos números, mismas semillas, mismo aspecto.
//
//   W2WPetDraw.colors                      los colores que se pueden elegir (como BrainyColors)
//   W2WPetDraw.mount(canvas, petJson, opts) → { update(petJson), setColor(key), destroy() }
//   W2WPetDraw.birth(container, petJson, { onDone }) → { skip(), setColor(key), update(petJson), petRect(), destroy() }
//
// petJson = el JSON tal cual lo da GET /api/pet. Script clásico (sin módulos ni eval): la CSP lo permite.
(function () {
  'use strict';

  var PI = Math.PI, TAU = 2 * Math.PI;

  function clamp(v, a, b) { return v < a ? a : (v > b ? b : v); }

  // ===== Colores =====
  var NEUTRAL = '#B8C0D0';
  var CHOICES = [
    ['blue', 'Azul', '#3F5BEA'],
    ['purple', 'Morado', '#8B5CF6'],
    ['pink', 'Rosa', '#EC5C9A'],
    ['coral', 'Coral', '#F2694B'],
    ['orange', 'Naranja', '#F39A2B'],
    ['green', 'Verde', '#2FB36F'],
    ['teal', 'Turquesa', '#17A9B8']
  ];

  function hex(h) {
    var n = parseInt(h.slice(1), 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  }
  function colorOf(key) {
    for (var i = 0; i < CHOICES.length; i++) if (CHOICES[i][0] === key) return hex(CHOICES[i][2]);
    return hex(NEUTRAL);
  }
  function rgba(c, a) { return 'rgba(' + c[0] + ',' + c[1] + ',' + c[2] + ',' + (a === undefined ? 1 : clamp(a, 0, 1)) + ')'; }
  function lerpRgb(a, b, t) { return [Math.round(a[0] + (b[0] - a[0]) * t), Math.round(a[1] + (b[1] - a[1]) * t), Math.round(a[2] + (b[2] - a[2]) * t)]; }

  // Igual que HSLColor de Flutter: aclara/oscurece (y satura) sumando a la luminosidad.
  function shade(c, dl, ds) {
    var r = c[0] / 255, g = c[1] / 255, b = c[2] / 255;
    var max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min;
    var h = 0;
    if (max === 0 || d === 0) h = 0;
    else if (max === r) h = 60 * (((g - b) / d) % 6);
    else if (max === g) h = 60 * ((b - r) / d + 2);
    else h = 60 * ((r - g) / d + 4);
    if (isNaN(h)) h = 0;
    if (h < 0) h += 360;
    var l = (max + min) / 2;
    var s = l === 1 ? 0 : clamp(d / (1 - Math.abs(2 * l - 1)), 0, 1);
    l = clamp(l + dl, 0, 1);
    s = clamp(s + (ds || 0), 0, 1);
    var ch = (1 - Math.abs(2 * l - 1)) * s, sec = ch * (1 - Math.abs((h / 60) % 2 - 1)), m = l - ch / 2;
    var rr, gg, bb;
    if (h < 60) { rr = ch; gg = sec; bb = 0; } else if (h < 120) { rr = sec; gg = ch; bb = 0; } else if (h < 180) { rr = 0; gg = ch; bb = sec; } else if (h < 240) { rr = 0; gg = sec; bb = ch; } else if (h < 300) { rr = sec; gg = 0; bb = ch; } else { rr = ch; gg = 0; bb = sec; }
    return [Math.round((rr + m) * 255), Math.round((gg + m) * 255), Math.round((bb + m) * 255)];
  }

  var WHITE = [255, 255, 255], INK = [11, 18, 56], YELLOW = [255, 228, 92], PALE = [185, 203, 255], GOLD = [255, 216, 74], PINK = [255, 143, 177];
  // Colores de cada zona del cerebro (petColors), en el orden de las regiones del cerebro: path, memory, habit, words, links.
  var REGION_KEYS = ['path', 'memory', 'habit', 'words', 'links'];
  var REGION_COLORS = [hex('#4AC487'), hex('#7C9CFF'), hex('#F07A9A'), hex('#E6A64A'), hex('#B58CFF')];
  var NEURON_COLORS = ['#7C9CFF', '#4AC487', '#E6A64A', '#F07A9A', '#B58CFF', '#FFE45C'].map(hex);

  // ===== Curvas (las de Flutter) =====
  function cubic(a, b, c, d) {
    function ev(p, q, m) { return 3 * p * (1 - m) * (1 - m) * m + 3 * q * (1 - m) * m * m + m * m * m; }
    return function (t) {
      if (t <= 0) return 0;
      if (t >= 1) return 1;
      var s = 0, e = 1;
      for (var i = 0; i < 60; i++) {
        var mid = (s + e) / 2, est = ev(a, c, mid);
        if (Math.abs(t - est) < 0.001) return ev(b, d, mid);
        if (est < t) s = mid; else e = mid;
      }
      return ev(b, d, (s + e) / 2);
    };
  }
  var easeOutBack = cubic(0.175, 0.885, 0.32, 1.275);
  var easeInOutCubic = cubic(0.645, 0.045, 0.355, 1.0);
  var easeOutCubic = cubic(0.215, 0.61, 0.355, 1.0);
  var easeOut = cubic(0.25, 0.1, 0.25, 1.0);
  function elasticOut(t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    return Math.pow(2, -10 * t) * Math.sin((t - 0.1) * TAU / 0.4) + 1;
  }
  function span(t, from, to) { return clamp((t - from) / (to - from), 0, 1); }

  // ===== El cerebro: nube de 680 neuronas (BrainCloud), igual en todos los aparatos =====
  function mulberry32(seed) {
    var s = seed | 0;
    return function () {
      s = (s + 0x6D2B79F5) | 0;
      var t = Math.imul(s ^ (s >>> 15), 1 | s);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  var cloud = null;
  function brainCloud() {
    if (cloud) return cloud;
    var count = 680, rand = mulberry32(20261117);
    var xs = [], ys = [], zs = [], ph = [];
    function direction() {
      var u = rand() * 2 - 1, a = rand() * PI * 2, s = Math.sqrt(1 - u * u);
      return [s * Math.cos(a), u, s * Math.sin(a)];
    }
    function groove(x, y, z) {
      var n = Math.sin(11 * x + 3 * Math.sin(4 * z)) + Math.sin(9 * z + 2.5 * Math.sin(5 * y)) + Math.sin(10 * y + 2 * Math.sin(6 * x));
      return Math.exp(-Math.pow(n / 0.35, 2));
    }
    while (xs.length < count * 0.80) {
      var d = direction();
      var deep = rand() < 0.2;
      var r = deep ? 0.25 + 0.6 * rand() : 0.93 + 0.07 * rand();
      var x = d[0] * 0.74 * r, y = d[1] * 0.62 * r, z = d[2] * r;
      if (!deep) {
        var g = groove(x, y, z);
        if (g > 0.55 && rand() < 0.75) continue;
        var k = 1 - 0.07 * g;
        x *= k; y *= k; z *= k;
      }
      if (y < 0) y *= 0.72;
      x *= 1 - 0.13 * z;
      var ax = Math.abs(x);
      if (y > -0.1) y -= 0.16 * Math.exp(-Math.pow(ax / 0.1, 2));
      x = (x < 0 ? -1 : 1) * (ax * 0.93 + 0.045);
      var p;
      if (deep && r < 0.6) p = 4;
      else if (z < -0.42) p = 0;
      else if (y < -0.1 && ax > 0.28 && z < 0.5) p = 2;
      else if (z > 0.18) p = 3;
      else p = 1;
      xs.push(x); ys.push(y); zs.push(z); ph.push(p);
    }
    while (xs.length < count * 0.90) {
      var d2 = direction();
      var r2 = 0.85 + 0.15 * rand(), side = rand() < 0.5 ? -1 : 1;
      xs.push(side * 0.5 + d2[0] * 0.17 * r2);
      ys.push(-0.3 + d2[1] * 0.15 * r2);
      zs.push(0.12 + d2[2] * 0.42 * r2);
      ph.push(2);
    }
    while (xs.length < count) {
      var d3 = direction();
      var r3 = rand() < 0.25 ? 0.4 + 0.5 * rand() : 0.94 + 0.06 * rand();
      xs.push(d3[0] * 0.46 * r3);
      ys.push(-0.46 + d3[1] * 0.2 * r3);
      zs.push(-0.6 + d3[2] * 0.27 * r3);
      ph.push(4);
    }
    // Vista fija de tres cuartos.
    var yaw = -1.05, pitch = 0.20;
    var cy = Math.cos(yaw), syw = Math.sin(yaw), cp = Math.cos(pitch), sp = Math.sin(pitch);
    var n = xs.length, i, j;
    var sx = new Float32Array(n), sy = new Float32Array(n), depth = new Float32Array(n), region = new Uint8Array(ph);
    var rx = new Float32Array(n), ry = new Float32Array(n), rz = new Float32Array(n);
    for (i = 0; i < n; i++) {
      var x1 = xs[i] * cy + zs[i] * syw, z1 = -xs[i] * syw + zs[i] * cy;
      var y2 = ys[i] * cp - z1 * sp, z2 = ys[i] * sp + z1 * cp;
      rx[i] = x1; ry[i] = y2; rz[i] = z2;
      var persp = 2.6 / (2.6 - z2);
      sx[i] = x1 * persp;
      sy[i] = -y2 * persp;
      depth[i] = clamp((z2 + 1) / 2, 0, 1);
    }
    // Conexiones: cada neurona con sus 2 vecinas más cercanas (en 3D).
    var ea = [], eb = [], seen = {};
    for (i = 0; i < n; i++) {
      var b1 = -1, b2 = -1, d1 = Infinity, dd2 = Infinity;
      for (j = 0; j < n; j++) {
        if (j === i) continue;
        var dx = rx[i] - rx[j], dy = ry[i] - ry[j], dz = rz[i] - rz[j];
        var dd = dx * dx + dy * dy + dz * dz;
        if (dd < d1) { b2 = b1; dd2 = d1; b1 = j; d1 = dd; } else if (dd < dd2) { b2 = j; dd2 = dd; }
      }
      var pair = [b1, b2];
      for (var q = 0; q < 2; q++) {
        j = pair[q];
        if (j < 0) continue;
        var key = i < j ? i * n + j : j * n + i;
        if (!seen[key]) { seen[key] = 1; ea.push(i); eb.push(j); }
      }
    }
    var threshold = new Float32Array(n);
    for (i = 0; i < n; i++) threshold[i] = rand();
    var edgesOf = [];
    for (i = 0; i < n; i++) edgesOf.push([]);
    for (var e = 0; e < ea.length; e++) { edgesOf[ea[e]].push(e); edgesOf[eb[e]].push(e); }
    var lines = new Float32Array(ea.length * 4);
    for (e = 0; e < ea.length; e++) {
      lines[e * 4] = sx[ea[e]]; lines[e * 4 + 1] = sy[ea[e]]; lines[e * 4 + 2] = sx[eb[e]]; lines[e * 4 + 3] = sy[eb[e]];
    }
    var band = new Uint8Array(n);
    for (i = 0; i < n; i++) band[i] = depth[i] < 0.34 ? 0 : (depth[i] < 0.67 ? 1 : 2);
    cloud = { count: n, sx: sx, sy: sy, depth: depth, region: region, edgeA: new Uint16Array(ea), edgeB: new Uint16Array(eb), edgesOf: edgesOf, lines: lines, band: band, threshold: threshold };
    return cloud;
  }

  // Las señales que viajan por las conexiones (BrainSignals). Semilla 7, como en Flutter
  // (el generador es otro: Dart usa el suyo; aquí mulberry32, así que los caminos concretos no coinciden).
  function BrainSignals(count, seed) {
    var m = brainCloud(), rand = mulberry32(seed == null ? 7 : seed);
    this.rand = rand;
    this.glow = new Float32Array(m.count);
    this.edge = []; this.forward = []; this.t = []; this.speed = [];
    for (var i = 0; i < count; i++) {
      this.edge.push(Math.floor(rand() * m.edgeA.length));
      this.forward.push(rand() < 0.5);
      this.t.push(rand());
      this.speed.push(1.1 + rand() * (2.6 - 1.1));
    }
  }
  BrainSignals.prototype.step = function (dt) {
    var m = brainCloud(), glow = this.glow, i;
    for (i = 0; i < glow.length; i++) if (glow[i] > 0) glow[i] = Math.max(0, glow[i] - dt * 2.2);
    for (i = 0; i < this.edge.length; i++) {
      this.t[i] += dt * this.speed[i];
      if (this.t[i] < 1) continue;
      var e = this.edge[i];
      var arrived = this.forward[i] ? m.edgeB[e] : m.edgeA[e];
      glow[arrived] = 1;
      var options = m.edgesOf[arrived];
      var next = options[Math.floor(this.rand() * options.length)];
      if (next === e && options.length > 1) next = options[(options.indexOf(e) + 1) % options.length];
      this.edge[i] = next;
      this.forward[i] = m.edgeA[next] === arrived;
      this.t[i] = 0;
    }
  };

  // ===== JSON de GET /api/pet → estado (como PetState.tryParse en pet.dart) =====
  function isMap(v) { return v !== null && typeof v === 'object' && !Array.isArray(v); }
  function asMap(v) { return isMap(v) ? v : {}; }
  function asInt(v, f) { var n = typeof v === 'number' ? Math.trunc(v) : parseInt(v, 10); return isNaN(n) ? (f || 0) : n; }
  function asNum(v, f) { var n = typeof v === 'number' ? v : parseFloat(v); return isNaN(n) ? (f || 0) : n; }
  function text(v) { return typeof v === 'string' && v.length ? v : null; }

  function parseCare(json) {
    if (!isMap(json)) return null;
    var needs = asMap(json.needs);
    if (!Object.keys(needs).length) return null;
    return {
      mood: json.mood == null ? 'ok' : String(json.mood),
      asleep: json.asleep === true,
      hibernating: json.hibernating === true,
      sick: json.sick === true,
      form: text(json.form),
      leaning: text(json.leaning)
    };
  }

  function parsePet(json) {
    var j = asMap(json);
    var pet = { name: 'Brainy', color: null, stage: 0, levels: [0, 0, 0, 0, 0], care: null, valid: false };
    if (!isMap(j.stage) || !isMap(j.regions)) return pet;
    var s = j.stage, regions = j.regions;
    var count = clamp(asInt(s.count, 5), 1, 12);
    pet.valid = true;
    pet.name = j.name == null ? 'Brainy' : String(j.name);
    pet.color = typeof j.color === 'string' ? j.color : null;
    pet.stage = clamp(asInt(s.index), 0, count - 1);
    for (var r = 0; r < 5; r++) pet.levels[r] = clamp(asNum(asMap(regions[REGION_KEYS[r]]).level), 0, 1);
    pet.care = parseCare(j.care);
    return pet;
  }

  // ===== Dibujo de la mascota (PetPainter). Hoja de 400 × 420, pies en y = 392 =====
  var STAGE_SCALE = [0.62, 0.74, 0.84, 0.92, 1.0];
  var BRAIN_C = [200, 181], BRAIN_R = 73;

  function sheet(w, h) {
    var s = Math.min(w, h) / 452;
    return [s, (w - 400 * s) / 2, (h - 420 * s) / 2 + 6 * s];
  }

  function rrectPath(ctx, x, y, w, h, r) {
    r = Math.min(r, w / 2, h / 2);
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }
  function oval(ctx, cx, cy, w, h, fill) {
    if (w <= 0 || h <= 0) return;
    ctx.beginPath();
    ctx.ellipse(cx, cy, w / 2, h / 2, 0, 0, TAU);
    ctx.fillStyle = fill;
    ctx.fill();
  }
  function circle(ctx, cx, cy, r, fill) {
    if (r <= 0) return;
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, TAU);
    ctx.fillStyle = fill;
    ctx.fill();
  }
  function radial(ctx, cx, cy, r, colors, stops) {
    var g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
    for (var i = 0; i < colors.length; i++) g.addColorStop(stops ? stops[i] : i / (colors.length - 1), colors[i]);
    return g;
  }
  function pen(ctx, color, width, cap) {
    ctx.strokeStyle = color;
    ctx.lineWidth = width;
    ctx.lineCap = cap || 'butt';
    ctx.lineJoin = 'miter';
  }
  // Muchos puntos redondos de una vez (como drawRawPoints): un solo trazado.
  function dots(ctx, xy, n, radius, color) {
    if (n <= 0 || radius <= 0) return;
    ctx.beginPath();
    for (var i = 0; i < n; i += 2) {
      ctx.moveTo(xy[i] + radius, xy[i + 1]);
      ctx.arc(xy[i], xy[i + 1], radius, 0, TAU);
    }
    ctx.fillStyle = color;
    ctx.fill();
  }
  function segments(ctx, xy, n, width, color, cap) {
    if (n <= 0) return;
    ctx.beginPath();
    for (var i = 0; i + 3 < n; i += 4) {
      ctx.moveTo(xy[i], xy[i + 1]);
      ctx.lineTo(xy[i + 2], xy[i + 3]);
    }
    pen(ctx, color, width, cap);
    ctx.stroke();
  }

  // Cubos reutilizables para agrupar las neuronas (sin crear arrays en cada cuadro).
  var buckets = null;
  function getBuckets() {
    if (buckets) return buckets;
    var n = brainCloud().count * 2;
    buckets = { white: [], whiteN: [0, 0, 0], lit: [], litN: [] };
    for (var b = 0; b < 3; b++) buckets.white.push(new Float32Array(n));
    for (var p = 0; p < 5; p++) {
      buckets.lit.push([new Float32Array(n), new Float32Array(n), new Float32Array(n)]);
      buckets.litN.push([0, 0, 0]);
    }
    return buckets;
  }

  // El cerebro dentro de la cúpula: blancas las no aprendidas; las aprendidas con el color de su zona.
  function drawBrain(ctx, pet, signals) {
    var m = brainCloud(), B = getBuckets(), lv = pet.levels, i, b, p;
    function on(k) { return m.threshold[k] < lv[m.region[k]]; }
    ctx.save();
    ctx.translate(BRAIN_C[0], BRAIN_C[1]);
    ctx.scale(BRAIN_R, BRAIN_R);
    var u = 1 / BRAIN_R;

    segments(ctx, m.lines, m.lines.length, 0.6 * u, rgba(PALE, 0.13));

    B.whiteN[0] = B.whiteN[1] = B.whiteN[2] = 0;
    for (p = 0; p < 5; p++) B.litN[p][0] = B.litN[p][1] = B.litN[p][2] = 0;
    for (i = 0; i < m.count; i++) {
      b = m.band[i];
      var arr, idx;
      if (on(i)) { p = m.region[i]; arr = B.lit[p][b]; idx = B.litN[p][b]; B.litN[p][b] = idx + 2; }
      else { arr = B.white[b]; idx = B.whiteN[b]; B.whiteN[b] = idx + 2; }
      arr[idx] = m.sx[i]; arr[idx + 1] = m.sy[i];
    }
    for (b = 0; b < 3; b++) dots(ctx, B.white[b], B.whiteN[b], (1.8 + 0.7 * b) * u / 2, rgba(WHITE, 0.34 + 0.22 * b));
    for (p = 0; p < 5; p++) {
      var base = REGION_COLORS[p];
      for (b = 0; b < 3; b++) {
        var nn = B.litN[p][b];
        if (!nn) continue;
        dots(ctx, B.lit[p][b], nn, (5.4 + 1.6 * b) * u / 2, rgba(base, 0.22));
        dots(ctx, B.lit[p][b], nn, (2.5 + 1.0 * b) * u / 2, rgba(base, 0.60 + 0.20 * b));
      }
    }

    if (signals) {
      var glow = signals.glow;
      for (i = 0; i < m.count; i++) {
        var gl = glow[i];
        if (gl <= 0.02) continue;
        var fc = on(i) ? lerpRgb(REGION_COLORS[m.region[i]], WHITE, 0.75) : WHITE;
        circle(ctx, m.sx[i], m.sy[i], (1.4 + 1.8 * gl) * u, rgba(fc, 0.75 * gl));
      }
      var halo = rgba(YELLOW, 0.35);
      for (i = 0; i < signals.edge.length; i++) {
        var e = signals.edge[i], fw = signals.forward[i];
        var ia = fw ? m.edgeA[e] : m.edgeB[e], ib = fw ? m.edgeB[e] : m.edgeA[e];
        var fx = m.sx[ia], fy = m.sy[ia], tx = m.sx[ib], ty = m.sy[ib], st = signals.t[i], tt = Math.max(0, st - 0.55);
        var px = fx + (tx - fx) * st, py = fy + (ty - fy) * st, qx = fx + (tx - fx) * tt, qy = fy + (ty - fy) * tt;
        var bright = on(ia) && on(ib);
        if (Math.hypot(px - qx, py - qy) > 0.3 * u) {
          var gr = ctx.createLinearGradient(qx, qy, px, py);
          if (bright) { gr.addColorStop(0, 'rgba(255,228,92,0)'); gr.addColorStop(1, 'rgba(255,243,176,0.902)'); }
          else { gr.addColorStop(0, 'rgba(255,255,255,0)'); gr.addColorStop(1, 'rgba(255,255,255,0.502)'); }
          ctx.beginPath();
          ctx.moveTo(qx, qy);
          ctx.lineTo(px, py);
          pen(ctx, gr, 1.5 * u, 'round');
          ctx.stroke();
        }
        if (bright) circle(ctx, px, py, 3.2 * u, halo);
        circle(ctx, px, py, (bright ? 1.5 : 1.0) * u, '#FFFFFF');
      }
    }
    ctx.restore();
  }

  function drawFace(ctx, t, moving, stage, mood, resting, glasses, eyes) {
    var whitePen = function (w) { pen(ctx, '#FFFFFF', w || 5.5, 'round'); };
    var cheek = mood === 'sick' ? 'rgba(74,196,135,0.6)' : 'rgba(255,143,177,0.6)';
    oval(ctx, 136, 306, 30, 20, cheek);
    oval(ctx, 264, 306, 30, 20, cheek);

    var blink = moving && (t * 6) % 3 > 2.9;
    var lookUp = mood === 'hungry' ? -5 : 0;
    var xs = [164, 236];
    for (var k = 0; k < 2; k++) {
      var cx = xs[k];
      if (eyes != null && eyes > 0.08) {
        ctx.save();
        ctx.translate(cx, 284);
        ctx.scale(1, eyes);
        ctx.translate(-cx, -284);
        oval(ctx, cx, 284, 34, 40, '#FFFFFF');
        circle(ctx, cx, 288, 11, rgba(INK));
        circle(ctx, cx + 4, 283, 4.2, '#FFFFFF');
        ctx.restore();
      } else if (resting || eyes != null) {
        ctx.beginPath();
        ctx.moveTo(cx - 15, 282);
        ctx.quadraticCurveTo(cx, 296, cx + 15, 282);
        whitePen(); ctx.stroke();
      } else if (stage === 0 || blink) {
        ctx.beginPath();
        ctx.moveTo(cx - 15, 290);
        ctx.quadraticCurveTo(cx, 272, cx + 15, 290);
        whitePen(); ctx.stroke();
      } else {
        oval(ctx, cx, 284, 34, 40, '#FFFFFF');
        circle(ctx, cx, 288 + lookUp, 11, rgba(INK));
        circle(ctx, cx + 4, 283 + lookUp, 4.2, '#FFFFFF');
        circle(ctx, cx - 4, 293 + lookUp, 2, 'rgba(255,255,255,0.8)');
      }
    }
    if (glasses && !resting) {
      pen(ctx, rgba(GOLD), 5);
      ctx.beginPath(); ctx.arc(164, 284, 27, 0, TAU); ctx.stroke();
      ctx.beginPath(); ctx.arc(236, 284, 27, 0, TAU); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(191, 284); ctx.lineTo(209, 284); ctx.stroke();
    }
    if (resting) {
      circle(ctx, 200, 322, 5, '#FFFFFF');
    } else if (mood === 'hungry') {
      oval(ctx, 200, 324, 18, 22, rgba(INK));
    } else if (mood === 'sick') {
      ctx.beginPath();
      ctx.moveTo(180, 322);
      ctx.quadraticCurveTo(190, 312, 200, 322);
      ctx.quadraticCurveTo(210, 332, 220, 322);
      whitePen(); ctx.stroke();
    } else if (mood === 'bored' || mood === 'messy') {
      ctx.beginPath(); ctx.moveTo(186, 322); ctx.lineTo(214, 322);
      whitePen(); ctx.stroke();
    } else if (stage === 0) {
      ctx.beginPath();
      ctx.moveTo(192, 320);
      ctx.quadraticCurveTo(200, 324, 208, 320);
      whitePen(4.5); ctx.stroke();
    } else if (stage >= 3) {
      ctx.beginPath();
      ctx.moveTo(182, 312);
      ctx.quadraticCurveTo(200, 306, 218, 312);
      ctx.quadraticCurveTo(218, 338, 200, 338);
      ctx.quadraticCurveTo(182, 338, 182, 312);
      ctx.closePath();
      ctx.fillStyle = rgba(INK);
      ctx.fill();
      oval(ctx, 200, 331, 20, 12, rgba(PINK));
    } else {
      ctx.beginPath();
      ctx.moveTo(182, 314);
      ctx.quadraticCurveTo(200, 334, 218, 314);
      whitePen(); ctx.stroke();
    }
  }

  function drawZzz(ctx, cx, cy, t, moving) {
    for (var i = 0; i < 3; i++) {
      var rise = moving ? ((t * 2 + i / 3) % 1) : i / 3;
      var s = 11 + 8 * rise, ox = cx + 32 * rise + 10 * i, oy = cy - 58 * rise;
      ctx.beginPath();
      ctx.moveTo(ox - s, oy - s);
      ctx.lineTo(ox + s, oy - s);
      ctx.lineTo(ox - s, oy + s);
      ctx.lineTo(ox + s, oy + s);
      pen(ctx, rgba(PALE, 0.95 - 0.7 * rise), 5, 'round');
      ctx.lineJoin = 'round';
      ctx.stroke();
    }
  }

  function starPath(ctx, cx, cy, r, inner) {
    ctx.beginPath();
    for (var i = 0; i < 8; i++) {
      var a = -PI / 2 + i * PI / 4, d = i % 2 === 0 ? r : r * inner;
      var x = cx + Math.cos(a) * d, y = cy + Math.sin(a) * d;
      if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
    }
    ctx.closePath();
  }

  function drawVoice(ctx, cx, cy, t, moving, color, left) {
    var c = shade(color, 0.22);
    for (var i = 0; i < 3; i++) {
      var alpha = moving ? 0.25 + 0.6 * (0.5 + 0.5 * Math.sin((t * 4 - i * 0.22) * TAU)) : 0.7;
      var r = 14 + 12 * i, a0 = left ? PI - 0.7 : -0.7;
      ctx.beginPath();
      ctx.arc(cx, cy, r, a0, a0 + 1.4);
      pen(ctx, rgba(c, alpha), 5, 'round');
      ctx.stroke();
    }
  }

  function drawGlow(ctx, k, t, moving) {
    var pulse = moving ? 0.5 + 0.5 * Math.sin(t * TAU) : 0.5;
    var r = (200 + 8 * pulse) * k, cx = 200, cy = 392 - 160 * k;
    circle(ctx, cx, cy, r, radial(ctx, cx, cy, r, ['rgba(255,228,92,0.333)', 'rgba(181,140,255,0.133)', 'rgba(181,140,255,0)'], [0.55, 0.85, 1]));
  }

  // Dibuja la mascota en el rectángulo (x0, y0, w, h) del contexto.
  // time: 0–1 en bucle (6 s) o null = quieta. pose: la del nacimiento (null = entera).
  function drawPet(ctx, x0, y0, w, h, pet, time, fit, signals, pose) {
    var t = time == null ? 0 : time, moving = time != null;
    var stage = clamp(pet.stage, 0, 4);
    var care = pet.care, mood = care ? care.mood : '', resting = care ? (care.asleep || care.hibernating) : false;
    var form = stage >= 4 && care ? care.form : null;
    var color = colorOf(pet.color);
    var sh = sheet(w, h), s = sh[0];

    ctx.save();
    ctx.translate(x0 + sh[1], y0 + sh[2]);
    ctx.scale(s, s);

    var bodyIn = pose ? pose.body : 1, domeIn = pose ? pose.dome : 1, antennaIn = pose ? pose.antenna : 1, sparkIn = pose ? pose.spark : 1;
    var lift = pose ? pose.lift : 0;
    var k = fit ? 1 : STAGE_SCALE[stage];
    var breath = moving && !pose ? 1 + 0.012 * Math.sin(t * TAU * 2) : 1;
    if (stage >= 4 && !pose) drawGlow(ctx, k, t, moving);
    var ground = clamp(bodyIn, 0, 1) * clamp(1 - lift / 90, 0.4, 1);
    if (ground > 0) oval(ctx, 200, 396, 192 * k * ground, 22 * k * ground, 'rgba(5,10,42,' + (0.25 * ground) + ')');

    ctx.translate(200, 392 - lift);
    ctx.scale(k * breath, k * breath);
    if (pose && pose.squash) ctx.scale(1 + 0.6 * pose.squash, 1 - pose.squash);
    ctx.translate(-200, -392);

    var light = shade(color, 0.16), dark = shade(color, -0.20), darker = shade(color, -0.27);

    // Antena con su chispa.
    if (antennaIn > 0) {
      ctx.save();
      ctx.translate(200, 120);
      ctx.scale(antennaIn, antennaIn);
      ctx.translate(-200, -120);
      ctx.beginPath();
      ctx.moveTo(200, 120);
      ctx.bezierCurveTo(200, 108, 196, 100, 200, 90);
      pen(ctx, rgba(shade(color, 0.28)), 5, 'round');
      ctx.stroke();
      if (sparkIn > 0) {
        var pulse = moving ? 0.5 + 0.5 * Math.sin(t * TAU * 3) : 0.5;
        var sg = (26 + 6 * pulse) * sparkIn;
        circle(ctx, 200, 78, sg, radial(ctx, 200, 78, sg, ['rgba(255,228,92,0.902)', 'rgba(255,228,92,0)']));
        circle(ctx, 200, 78, (stage === 0 ? 15 : 11) * sparkIn, rgba(YELLOW));
        circle(ctx, 196, 74, 4 * sparkIn, 'rgba(255,255,255,0.902)');
      }
      ctx.restore();
    }
    // Forma «equilibrada»: una estrella sobre la chispa.
    if (form === 'balanced' && !pose) {
      var sk = moving ? 0.85 + 0.15 * Math.sin(t * TAU * 2) : 1;
      starPath(ctx, 200, 36, 15 * sk, 0.40);
      ctx.fillStyle = rgba(GOLD);
      ctx.fill();
    }

    // El cuerpo entero.
    if (bodyIn > 0) {
      ctx.save();
      if (bodyIn !== 1) {
        ctx.translate(200, 170);
        ctx.scale(0.3 + 0.7 * bodyIn, 0.3 + 0.7 * bodyIn);
        ctx.translate(-200, -170);
      }
      if (form === 'listener') {
        for (var side = -1; side <= 1; side += 2) {
          oval(ctx, 200 + side * 118, 176, 50, 78, rgba(dark));
          oval(ctx, 200 + side * 118, 176, 28, 56, 'rgba(255,143,177,0.533)');
        }
      }
      if (stage >= 2) {
        oval(ctx, 160, 378, 60, 30, rgba(darker));
        oval(ctx, 240, 378, 60, 30, rgba(darker));
        var wave = moving && !resting ? 0.10 * Math.sin(t * TAU * 3) : 0;
        for (var sd = -1; sd <= 1; sd += 2) {
          ctx.save();
          ctx.translate(200 + sd * 112, 272);
          ctx.rotate(-sd * (18 * PI / 180 + wave));
          var lg = ctx.createLinearGradient(0, -36, 0, 36);
          lg.addColorStop(0, rgba(shade(color, 0.04)));
          lg.addColorStop(1, rgba(dark));
          oval(ctx, 0, 0, 38, 72, lg);
          ctx.restore();
        }
      }
      if (mood === 'messy') {
        var dust = [[92, 372, 9], [112, 388, 6], [306, 376, 8], [286, 390, 5], [326, 390, 4.5]];
        ctx.beginPath();
        for (var di = 0; di < dust.length; di++) {
          ctx.moveTo(dust[di][0] + dust[di][2], dust[di][1]);
          ctx.arc(dust[di][0], dust[di][1], dust[di][2], 0, TAU);
        }
        ctx.fillStyle = 'rgba(160,133,91,0.6)';
        ctx.fill();
      }
      var bg = ctx.createLinearGradient(200, 100, 200, 380);
      bg.addColorStop(0, rgba(light));
      bg.addColorStop(0.45, rgba(color));
      bg.addColorStop(1, rgba(dark));
      rrectPath(ctx, 86, 106, 228, 272, 112);
      ctx.fillStyle = bg;
      ctx.fill();
      oval(ctx, 200, 318, 160, 116, radial(ctx, 200, 318, 80, ['rgba(255,255,255,0.3)', 'rgba(255,255,255,0)']));

      drawFace(ctx, t, moving, stage, mood, resting, form === 'scholar', pose ? pose.eyes : null);
      ctx.restore();
    }

    // Cúpula de cristal con el cerebro dentro.
    var glass = clamp(domeIn, 0, 1);
    if (glass > 0) {
      ctx.globalAlpha = glass;
      rrectPath(ctx, 110, 120, 180, 118, 59);
      ctx.fillStyle = radial(ctx, 200, 170, 110, ['#1B2760', '#070B24']);
      ctx.fill();
      ctx.globalAlpha = 1;
      ctx.save();
      rrectPath(ctx, 113, 123, 174, 112, 56);
      ctx.clip();
      drawBrain(ctx, pet, signals);
      ctx.restore();
      rrectPath(ctx, 110, 120, 180, 118, 59);
      pen(ctx, rgba(shade(color, 0.34), 0.85 * glass), 4);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(128, 164);
      ctx.bezierCurveTo(132, 142, 150, 130, 172, 128);
      pen(ctx, rgba(WHITE, 0.55 * glass), 5, 'round');
      ctx.stroke();
      circle(ctx, 184, 128, 3, rgba(WHITE, 0.55 * glass));
    }

    if (stage >= 3 && !resting && !pose) {
      drawVoice(ctx, 322, 322, t, moving, color, false);
      if (form === 'talker') drawVoice(ctx, 78, 322, t, moving, color, true);
    }
    if (resting && !pose) drawZzz(ctx, 302, 112, t, moving);
    ctx.restore();
  }

  // ===== Nacimiento (BirthTimeline + _BirthPainter + _SkyPainter) =====
  var GATHERED = 0.40, WIRED = 0.50, BURST = 0.66, DOMED = 0.71, BODIED = 0.85, SPARKED = 0.87, EYES_OPEN = 0.885, LANDED = 0.972;
  var BEATS = [0.50, 0.5533, 0.6067];
  // Golpes que vibran: [momento, fuerza 0 suave · 1 media · 2 fuerte].
  var TAPS = [[GATHERED, 0], [0.50, 0], [0.5533, 0], [0.6067, 1], [BURST, 2], [SPARKED, 0], [LANDED, 1]];
  var VIBRATE_MS = [10, 20, 35];
  var BIRTH_MS = 7000, SKY_MS = 4000, CLOCK_MS = 6000;

  function birthPose(t, newborn) {
    var eyes = easeOutBack(span(t, EYES_OPEN, 0.915));
    var blink = span(t, 0.925, 0.94);
    if (blink > 0 && blink < 1) eyes *= 1 - Math.sin(blink * PI);
    if (newborn) eyes *= 1 - span(t, 0.985, 1.0);
    var crouch = span(t, 0.93, 0.945), jump = span(t, 0.945, LANDED), land = span(t, LANDED, 0.99);
    var squash = 0;
    if (crouch > 0 && crouch < 1) squash = 0.05 * Math.sin(crouch * PI);
    if (land > 0 && land < 1) squash = 0.07 * Math.sin(land * PI);
    return {
      dome: span(t, BURST, DOMED),
      body: easeOutBack(span(t, DOMED, BODIED)),
      antenna: easeOutBack(span(t, 0.83, 0.88)),
      spark: elasticOut(span(t, SPARKED, 0.93)),
      eyes: eyes,
      lift: jump > 0 && jump < 1 ? 30 * Math.sin(jump * PI) : 0,
      squash: squash
    };
  }

  function rnd(i, salt) {
    var x = Math.sin(i * 127.1 + salt * 311.7) * 43758.5453;
    return x - Math.floor(x);
  }

  function drawSky(ctx, w, h, phase) {
    var cx = w / 2, cy = h / 2 - 0.35 * h / 2, r = 1.1 * Math.min(w, h);
    ctx.fillStyle = radial(ctx, cx, cy, r, ['#1B3FAF', '#0F2A86', '#09195A'], [0, 0.55, 1]);
    ctx.fillRect(0, 0, w, h);
    for (var i = 0; i < 70; i++) {
      var blink = 0.5 + 0.5 * Math.sin((phase + rnd(i, 23)) * TAU);
      circle(ctx, rnd(i, 21) * w, rnd(i, 22) * h, 0.6 + 1.5 * rnd(i, 24), rgba(WHITE, 0.12 + 0.55 * blink * rnd(i, 25)));
    }
  }

  // El cerebro mientras se forma (neuronas volando en remolino, conexiones, latidos).
  function birthBrain(ctx, t, thump, alpha) {
    var m = brainCloud();
    ctx.save();
    ctx.translate(BRAIN_C[0], BRAIN_C[1]);
    var sc = BRAIN_R * (1 + 0.07 * thump);
    ctx.scale(sc, sc);
    var u = 1 / BRAIN_R;
    var g = t / GATHERED;
    var home = [[], [], []], heads = [], young = [], near = [], far = [], flash = [];
    var arrived = 0;
    function at(p, out, rho, th, far0, swirl) {
      var e = easeInOutCubic(clamp(p, 0, 1));
      var r = far0 + (rho - far0) * e, a = th + (1 - e) * swirl;
      out.push(r * Math.cos(a), r * Math.sin(a));
    }
    for (var i = 0; i < m.count; i++) {
      var q = (g - rnd(i, 1) * 0.58) / 0.42;
      if (q <= 0) continue;
      if (q >= 1) {
        arrived++;
        home[m.band[i]].push(m.sx[i], m.sy[i]);
        if (q < 1.22) flash.push(m.sx[i], m.sy[i]);
        continue;
      }
      var rho = Math.sqrt(m.sx[i] * m.sx[i] + m.sy[i] * m.sy[i]), th = Math.atan2(m.sy[i], m.sx[i]);
      var far0 = 6.5 + 2.5 * rnd(i, 4), swirl = 1.6 + 1.6 * rnd(i, 3);
      if (q < 0.18) { at(q, young, rho, th, far0, swirl); continue; }
      at(q, heads, rho, th, far0, swirl);
      at(q - 0.05, near, rho, th, far0, swirl);
      at(q, near, rho, th, far0, swirl);
      at(q - 0.11, far, rho, th, far0, swirl);
      at(q - 0.05, far, rho, th, far0, swirl);
    }
    var fed = arrived / m.count;

    var seed = (36 + 70 * fed) * (1 + 0.25 * thump) * u;
    circle(ctx, 0, 0, seed, radial(ctx, 0, 0, seed, [rgba(PALE, (0.50 + 0.25 * thump) * alpha), 'rgba(185,203,255,0)']));
    if (fed < 1) circle(ctx, 0, 0, 5 * u * (1 - fed), rgba(WHITE, 0.9 * (1 - fed)));

    var wiring = span(t, GATHERED, WIRED);
    if (wiring > 0) {
      var n = Math.floor(m.edgeA.length * wiring);
      if (n > 0) segments(ctx, m.lines, n * 4, 0.7 * u, rgba(PALE, clamp(0.13 + 0.50 * Math.sin(wiring * PI) + 0.30 * thump, 0, 1) * alpha));
    }
    segments(ctx, far, far.length, 1.2 * u, rgba(PALE, 0.22 * alpha), 'round');
    segments(ctx, near, near.length, 1.6 * u, rgba(PALE, 0.50 * alpha), 'round');
    dots(ctx, young, young.length, 1.0 * u, rgba(WHITE, 0.35 * alpha));
    dots(ctx, heads, heads.length, 3.75 * u, rgba(PALE, 0.16 * alpha));
    dots(ctx, heads, heads.length, 1.4 * u, rgba(WHITE, 0.95 * alpha));
    for (var b = 0; b < 3; b++) dots(ctx, home[b], home[b].length, (1.8 + 0.7 * b) * u / 2, rgba(WHITE, clamp(0.34 + 0.22 * b + 0.30 * thump, 0, 1) * alpha));
    dots(ctx, flash, flash.length, 2.3 * u, rgba(WHITE, 0.55 * alpha));
    ctx.restore();
  }

  // Las luces del nacimiento, en la misma hoja que la mascota (box = lado del cuadro de la mascota, centrado en cx, cy).
  function drawBirthLights(ctx, cx, cy, box, t, sky) {
    var sh = sheet(box, box), s = sh[0];
    ctx.save();
    ctx.translate(cx - box / 2 + sh[1], cy - box / 2 + sh[2]);
    ctx.scale(s, s);
    var bcx = BRAIN_C[0], bcy = BRAIN_C[1], bodyX = 200, bodyY = 240;
    var dome = span(t, BURST, DOMED);

    var halo = easeOut(span(t, DOMED, BODIED));
    if (halo > 0) {
      var hr = 285 * (1 + 0.04 * Math.sin(sky * TAU));
      circle(ctx, bodyX, bodyY, hr, radial(ctx, bodyX, bodyY, hr, ['rgba(223,231,255,' + (0.55 * halo) + ')', rgba(PALE, 0.30 * halo), 'rgba(185,203,255,0)'], [0, 0.6, 1]));
    }

    var thump = 0;
    for (var bi = 0; bi < BEATS.length; bi++) {
      var p = span(t, BEATS[bi], BEATS[bi] + 0.07);
      if (p <= 0 || p >= 1) continue;
      thump = Math.max(thump, Math.sin(Math.min(1, p * 2.4) * PI));
      ctx.beginPath();
      ctx.arc(bcx, bcy, 80 + 210 * easeOutCubic(p), 0, TAU);
      pen(ctx, rgba(YELLOW, 0.7 * (1 - p)), 8 * (1 - p));
      ctx.stroke();
    }

    if (dome < 1) birthBrain(ctx, t, thump, 1 - dome);

    var burst = span(t, BURST, 0.84);
    if (burst > 0 && burst < 1) {
      var fl = Math.sin(span(burst, 0, 0.5) * PI);
      if (fl > 0) {
        var fr = 130 + 420 * fl;
        circle(ctx, bcx, bcy, fr, radial(ctx, bcx, bcy, fr, [rgba(WHITE, 0.95 * fl), rgba(WHITE, 0.35 * fl), 'rgba(255,255,255,0)'], [0, 0.35, 1]));
      }
      var wave = easeOutCubic(burst);
      ctx.beginPath();
      ctx.arc(bcx, bcy, 70 + 480 * wave, 0, TAU);
      pen(ctx, rgba(WHITE, 0.75 * (1 - burst)), 14 * (1 - burst));
      ctx.stroke();
      var eb = easeOutCubic(burst);
      for (var i = 0; i < 28; i++) {
        var a = i * TAU / 28 + rnd(i, 7) * 0.5;
        var d = 90 + (230 + 260 * rnd(i, 8)) * eb;
        var dx = Math.cos(a), dy = Math.sin(a), fall = 110 * burst * burst, d0 = d - 34 * (1 - burst);
        ctx.beginPath();
        ctx.moveTo(bcx + dx * d0, bcy + dy * d0 + fall);
        ctx.lineTo(bcx + dx * d, bcy + dy * d + fall);
        pen(ctx, rgba(NEURON_COLORS[i % NEURON_COLORS.length], 1 - burst), 6 * (1 - burst * 0.6), 'round');
        ctx.stroke();
      }
    }

    var lit = span(t, SPARKED, 0.95);
    if (lit > 0 && lit < 1) {
      var grow = easeOutCubic(lit), fade = 1 - lit, tr = 20 + 70 * grow;
      circle(ctx, 200, 78, tr, radial(ctx, 200, 78, tr, ['rgba(255,243,176,' + (0.8 * fade) + ')', 'rgba(255,228,92,0)']));
      ctx.beginPath();
      for (var kk = 0; kk < 4; kk++) {
        var rx = Math.cos(kk * PI / 2), ry = Math.sin(kk * PI / 2);
        ctx.moveTo(200 + rx * (22 + 20 * grow), 78 + ry * (22 + 20 * grow));
        ctx.lineTo(200 + rx * (30 + 75 * grow), 78 + ry * (30 + 75 * grow));
      }
      pen(ctx, 'rgba(255,243,176,' + (0.9 * fade) + ')', 5 * fade, 'round');
      ctx.stroke();
    }

    var after = span(t, 0.86, 1.0);
    if (after > 0) {
      for (var w = 0; w < 12; w++) {
        var ta = w * TAU / 12 + rnd(w, 11) * 0.6;
        var td = 273 + 105 * rnd(w, 12);
        var bl = clamp(0.5 + 0.5 * Math.sin((sky + rnd(w, 13)) * TAU), 0, 1);
        starPath(ctx, bodyX + Math.cos(ta) * td, bodyY + Math.sin(ta) * 0.86 * td, (8 + 10 * rnd(w, 14)) * (0.5 + 0.5 * bl), 0.34);
        ctx.fillStyle = rgba(NEURON_COLORS[w % NEURON_COLORS.length], after * (0.35 + 0.65 * bl));
        ctx.fill();
      }
    }
    ctx.restore();
  }

  // Dónde va la mascota en la bienvenida: lado del cuadro como en Flutter (62 % del lado corto, máx. 260),
  // y centrada en lo que queda arriba si debajo hacen falta [below] px para la pregunta.
  function birthLayout(w, h, below) {
    var side = Math.min(Math.min(w, h) * 0.62, 260);
    var top = Math.max(16, (h - (side + 18 + below)) / 2);
    return { side: side, x: (w - side) / 2, y: top, cx: w / 2, cy: top + side / 2 };
  }

  // Un cuadro entero de la bienvenida: cielo, luces y la mascota naciendo.
  function drawBirthFrame(ctx, w, h, pet, t, sky, petTime, signals, below) {
    var L = birthLayout(w, h, below);
    drawSky(ctx, w, h, sky);
    var close = 1 - easeInOutCubic(clamp((t - 0.88) / 0.12, 0, 1));
    var zoom = 1 + 0.5 * close;
    ctx.save();
    ctx.translate(L.cx, L.cy + 70 * close);
    ctx.scale(zoom, zoom);
    var box = L.side * 0.86;
    drawBirthLights(ctx, 0, 0, box, t, sky);
    drawPet(ctx, -box / 2, -box / 2, box, box, pet, petTime, true, signals, t < 1 ? birthPose(t, pet.stage === 0) : null);
    ctx.restore();
    return L;
  }

  // ===== Montaje en la página =====
  function reducedMotion() {
    try { return !!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches); } catch (e) { return false; }
  }
  function onReducedChange(fn) {
    try {
      var mq = window.matchMedia('(prefers-reduced-motion: reduce)');
      if (mq.addEventListener) { mq.addEventListener('change', fn); return function () { mq.removeEventListener('change', fn); }; }
      if (mq.addListener) { mq.addListener(fn); return function () { mq.removeListener(fn); }; }
    } catch (e) { /* sin soporte */ }
    return function () {};
  }

  // Lleva el tamaño del lienzo (CSS × devicePixelRatio). Devuelve [w, h] en px CSS (0 si aún no se ve).
  function fitCanvas(canvas, size) {
    var w = size || canvas.clientWidth, h = size || canvas.clientHeight;
    if (!w || !h) return [0, 0];
    var dpr = Math.min(window.devicePixelRatio || 1, 3);
    var pw = Math.round(w * dpr), ph = Math.round(h * dpr);
    if (canvas.width !== pw) canvas.width = pw;
    if (canvas.height !== ph) canvas.height = ph;
    var ctx = canvas.getContext('2d');
    ctx.setTransform(pw / w, 0, 0, ph / h, 0, 0);
    ctx.clearRect(0, 0, w, h);
    return [w, h];
  }

  // Bucle de animación compartido: para solo cuando el lienzo sale del DOM o la página se oculta.
  function makeLoop(canvas, frame) {
    var raf = 0, alive = true, last = null, seen = false, born = performance.now();
    function tick(now) {
      raf = 0;
      if (!alive) return;
      if (canvas.isConnected) seen = true;
      else if (seen || now - born > 5000) { alive = false; return; } // lo quitaron de la página: se acabó
      if (document.hidden) { last = null; return; }
      var dt = last == null ? 0 : Math.min(0.1, (now - last) / 1000);
      last = now;
      frame(now, dt);
      raf = requestAnimationFrame(tick);
    }
    function onVis() { if (!document.hidden && alive && !raf && running) raf = requestAnimationFrame(tick); }
    var running = false;
    document.addEventListener('visibilitychange', onVis);
    return {
      start: function () { running = true; if (alive && !raf) raf = requestAnimationFrame(tick); },
      stop: function () { running = false; if (raf) cancelAnimationFrame(raf); raf = 0; last = null; },
      destroy: function () { alive = false; running = false; if (raf) cancelAnimationFrame(raf); raf = 0; document.removeEventListener('visibilitychange', onVis); },
      get alive() { return alive; }
    };
  }

  function mount(canvas, petJson, opts) {
    opts = opts || {};
    var pet = parsePet(petJson);
    if (opts.size) { canvas.style.width = opts.size + 'px'; canvas.style.height = opts.size + 'px'; }
    var ctx = canvas.getContext('2d');
    var signals = null, t0 = performance.now();

    function still() { return !!opts.still || reducedMotion(); }
    function draw(now) {
      var wh = fitCanvas(canvas, opts.size);
      if (!wh[0]) return;
      if (!signals) signals = new BrainSignals(Math.min(wh[0], wh[1]) < 120 ? 12 : 30);
      var moving = !still();
      var time = moving ? (((now - t0) / CLOCK_MS) % 1) : null;
      drawPet(ctx, 0, 0, wh[0], wh[1], pet, time, !!opts.fit, moving ? signals : null, null);
    }
    var loop = makeLoop(canvas, function (now, dt) {
      if (signals) signals.step(dt);
      draw(now);
    });
    function refresh() {
      if (still()) { loop.stop(); draw(performance.now()); } else loop.start();
    }
    var ro = null;
    if (window.ResizeObserver && !opts.size) {
      ro = new ResizeObserver(function () { if (still()) draw(performance.now()); });
      ro.observe(canvas);
    }
    var offReduce = onReducedChange(refresh);
    draw(performance.now());
    refresh();
    return {
      update: function (json) { pet = parsePet(json); if (still()) draw(performance.now()); },
      setColor: function (key) { pet.color = key || null; if (still()) draw(performance.now()); },
      destroy: function () { loop.destroy(); offReduce(); if (ro) ro.disconnect(); }
    };
  }

  function birth(container, petJson, opts) {
    opts = opts || {};
    var pet = parsePet(petJson);
    var below = opts.below == null ? 300 : opts.below;
    try { if (getComputedStyle(container).position === 'static') container.style.position = 'relative'; } catch (e) { /* nada */ }
    var canvas = document.createElement('canvas');
    canvas.setAttribute('aria-hidden', 'true');
    canvas.style.position = 'absolute';
    canvas.style.left = '0';
    canvas.style.top = '0';
    canvas.style.width = '100%';
    canvas.style.height = '100%';
    canvas.style.display = 'block';
    container.insertBefore(canvas, container.firstChild);
    var ctx = canvas.getContext('2d');

    var still = reducedMotion();
    var start = performance.now(), t = still ? 1 : 0, felt = 0, done = false, skipped = still, layout = null;
    var signals = null;

    function finish() {
      if (done) return;
      done = true;
      if (typeof opts.onDone === 'function') { try { opts.onDone(); } catch (e) { setTimeout(function () { throw e; }); } }
    }
    function haptics(now) {
      if (skipped || !navigator.vibrate) { felt = now; return; }
      for (var i = 0; i < TAPS.length; i++) {
        if (felt < TAPS[i][0] && now >= TAPS[i][0]) { try { navigator.vibrate(VIBRATE_MS[TAPS[i][1]]); } catch (e) { /* sin vibración */ } }
      }
      felt = now;
    }
    function draw(now) {
      var wh = fitCanvas(canvas);
      if (!wh[0]) return;
      if (!signals) signals = new BrainSignals(birthLayout(wh[0], wh[1], below).side * 0.86 < 120 ? 12 : 30);
      var sky = still ? 0 : ((now - start) / SKY_MS) % 1;
      var petTime = still ? null : ((now - start) / CLOCK_MS) % 1;
      layout = drawBirthFrame(ctx, wh[0], wh[1], pet, t, sky, petTime, still ? null : signals, below);
    }
    var loop = makeLoop(canvas, function (now, dt) {
      if (!done) {
        var nt = Math.min(1, (now - start) / BIRTH_MS);
        if (nt > t) { haptics(nt); t = nt; }
      }
      signals && signals.step(dt);
      draw(now);
      if (t >= 1) finish();
    });
    function skip() {
      if (t >= 1) return;
      skipped = true;
      t = 1;
      if (still) draw(performance.now());
      finish();
    }
    function onTap() { skip(); }
    container.addEventListener('pointerdown', onTap);
    var ro = null;
    if (window.ResizeObserver) { ro = new ResizeObserver(function () { if (still) draw(performance.now()); }); ro.observe(canvas); }

    draw(start);
    if (still) setTimeout(finish, 0); else loop.start();

    return {
      canvas: canvas,
      skip: skip,
      setColor: function (key) { pet.color = key || null; if (still) draw(performance.now()); },
      update: function (json) { pet = parsePet(json); if (still) draw(performance.now()); },
      // Dónde queda la mascota al terminar (px CSS dentro del contenedor): para poner la pregunta debajo.
      petRect: function () {
        var L = layout || birthLayout(canvas.clientWidth, canvas.clientHeight, below);
        return { x: L.x, y: L.y, size: L.side };
      },
      destroy: function () {
        loop.destroy();
        if (ro) ro.disconnect();
        container.removeEventListener('pointerdown', onTap);
        if (canvas.parentNode) canvas.parentNode.removeChild(canvas);
      }
    };
  }

  // ===== Ganchos para pruebas (dibujan un cuadro fijo, sin bucle ni devicePixelRatio) =====
  function testCanvas(canvas) {
    var ctx = canvas.getContext('2d');
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    return ctx;
  }

  window.W2WPetDraw = {
    colors: [{ key: null, name: 'Neutro', hex: NEUTRAL }].concat(CHOICES.map(function (c) { return { key: c[0], name: c[1], hex: c[2] }; })),
    mount: mount,
    birth: birth,
    parse: parsePet,
    // Cuántas neuronas del cerebro están encendidas (la misma regla con la que se colorean).
    litCount: function (petJson) {
      var m = brainCloud(), lv = parsePet(petJson).levels, lit = 0;
      for (var i = 0; i < m.count; i++) if (m.threshold[i] < lv[m.region[i]]) lit++;
      return { lit: lit, total: m.count };
    },
    // Un cuadro de la mascota: time 0–1 (null = quieta); signalsSeconds = cuántos segundos han corrido las señales.
    _drawAt: function (canvas, petJson, o) {
      o = o || {};
      var ctx = testCanvas(canvas), sig = null;
      if (o.signalsSeconds) {
        sig = new BrainSignals(Math.min(canvas.width, canvas.height) < 120 ? 12 : 30);
        for (var s = 0; s < o.signalsSeconds * 60; s++) sig.step(1 / 60);
      }
      drawPet(ctx, 0, 0, canvas.width, canvas.height, parsePet(petJson), o.time == null ? null : o.time, !!o.fit, sig, null);
    },
    _birthFrameAt: function (canvas, petJson, t, o) {
      o = o || {};
      var ctx = testCanvas(canvas);
      drawBirthFrame(ctx, canvas.width, canvas.height, parsePet(petJson), t, o.sky || 0, o.petTime == null ? null : o.petTime, null, o.below == null ? 300 : o.below);
    },
    _cloud: brainCloud
  };
})();
