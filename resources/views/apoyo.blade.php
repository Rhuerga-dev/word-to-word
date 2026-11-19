<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>Apoya mi desarrollo · W2W</title>
<link rel="icon" href="/app/icons/favicon-32.png?v=2">
<link rel="stylesheet" href="/legal.css">
</head>
<body>
<main>
<header><img src="/app/icons/apple-touch-icon.png?v=2" alt=""><b>W2W</b></header>
<h1>☕ Apoya mi desarrollo con un café</h1>
<p class="muted">W2W (Word to Word), de Huerga Labs · <a href="#en">English below</a></p>

<section>
<h2>Gracias por estar aquí</h2>
<p>W2W la hago yo solo, sin publicidad y sin vender tus datos. Si te ayuda a hablar inglés y quieres apoyar su desarrollo, puedes invitarme a un café. Es <b>totalmente voluntario</b>: la app funciona igual lo hagas o no, y no desbloquea nada.</p>
</section>

@if ($zelle)
<section>
<h2>Zelle (Estados Unidos)</h2>
<p>Desde la app de tu banco, envía a:</p>
<p class="pay">{{ $zelle }}</p>
</section>
@endif

@if ($paypal)
<section>
<h2>PayPal (resto del mundo)</h2>
<p><a class="pay" href="{{ $paypal }}" target="_blank" rel="noopener noreferrer">Abrir PayPal</a></p>
</section>
@endif

<section>
<h2>Otras formas de apoyar</h2>
<p>Usar la app, contarle a alguien que quiere aprender inglés y enviarme tus ideas desde <b>Ajustes → Enviar sugerencia</b> también ayuda mucho.</p>
<p><a href="/app/">Volver a W2W</a></p>
</section>

<h1 id="en">☕ Support my work with a coffee</h1>
<section>
<h2>Thank you for being here</h2>
<p>I build W2W on my own, with no ads and without selling your data. If it helps you speak English and you'd like to support its development, you can buy me a coffee. It is <b>completely voluntary</b>: the app works the same either way, and it unlocks nothing.</p>
</section>

@if ($zelle)
<section>
<h2>Zelle (United States)</h2>
<p>From your bank's app, send to:</p>
<p class="pay">{{ $zelle }}</p>
</section>
@endif

@if ($paypal)
<section>
<h2>PayPal (rest of the world)</h2>
<p><a class="pay" href="{{ $paypal }}" target="_blank" rel="noopener noreferrer">Open PayPal</a></p>
</section>
@endif

<section>
<h2>Other ways to help</h2>
<p>Using the app, telling someone who wants to learn English, and sending me your ideas from <b>Settings → Send a suggestion</b> help a lot too.</p>
<p><a href="/app/">Back to W2W</a></p>
</section>
</main>
</body>
</html>
