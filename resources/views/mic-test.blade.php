<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>Prueba de micrófono · W2W</title>
<link rel="icon" href="/app/icons/favicon-32.png?v=2">
<link rel="stylesheet" href="/mic-test.css?v=1">
</head>
<body>
<main>
<header><img src="/app/icons/apple-touch-icon.png?v=2" alt=""><b>W2W</b></header>
<h1>Prueba de micrófono</h1>
<p class="muted">Sirve para saber si un micrófono (el del carro, unos audífonos, el del teléfono) se oye lo bastante bien para practicar inglés hablando. Dura 10 segundos.</p>
<p class="note">Tu voz no sale de este teléfono: se analiza aquí mismo y no se envía ni se guarda en ningún servidor.</p>

<section id="setup">
  <label for="label">¿Qué estás probando?</label>
  <input id="label" type="text" maxlength="40" placeholder="Ej.: Carro estacionado" autocomplete="off">
  <div id="pick" hidden>
    <label for="device">Micrófono</label>
    <select id="device"></select>
  </div>
  <button id="start" type="button" class="primary">Empezar la prueba</button>
  <p id="error" class="bad" role="alert" hidden></p>
</section>

<section id="run" hidden aria-live="polite">
  <p id="step" class="step"></p>
  <p id="say" class="say" hidden>The quick brown fox jumps over the lazy dog. She sells sea shells by the sea shore.</p>
  <div class="meter" aria-hidden="true"><div id="level"></div></div>
  <p id="count" class="count"></p>
  <p class="muted">Micrófono en uso: <b id="using">—</b></p>
</section>

<section id="result" hidden>
  <h2 id="verdict"></h2>
  <p id="why"></p>
  <table>
    <tbody id="numbers"></tbody>
  </table>
  <p><audio id="play" controls></audio></p>
  <p class="muted">Escúchate: así te oye la app.</p>
  <button id="again" type="button" class="primary">Hacer otra prueba</button>
</section>

<section id="history" hidden>
  <h2>Tus pruebas</h2>
  <p class="muted">Haz una con el teléfono solo y otra con el carro, y compara. Se guardan solo en este teléfono.</p>
  <div class="scroll">
    <table>
      <thead><tr><th>Prueba</th><th>Nota</th><th>Voz / ruido</th><th>Agudos</th><th>Micrófono</th></tr></thead>
      <tbody id="rows"></tbody>
    </table>
  </div>
  <div class="actions">
    <button id="copy" type="button">Copiar resultados</button>
    <button id="clear" type="button">Borrar pruebas</button>
  </div>
  <textarea id="text" rows="6" readonly hidden></textarea>
  <p id="copied" class="muted" hidden>Copiado. Pégalo donde quieras enviarlo.</p>
</section>

<section>
  <h2>Cómo probar el carro</h2>
  <ol>
    <li>Conecta el teléfono al carro por Bluetooth y, con el carro <b>estacionado</b>, haz una prueba.</li>
    <li>Mira «Micrófono en uso»: si pone el del teléfono, elige el del carro en la lista y repite.</li>
    <li>Repite en marcha (que maneje otra persona), con el aire fuerte y con una ventana abierta.</li>
    <li>Compara con una prueba del teléfono solo, sin Bluetooth.</li>
  </ol>
</section>
</main>
<script src="/mic-test.js?v=1"></script>
</body>
</html>
