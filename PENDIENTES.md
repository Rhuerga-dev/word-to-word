# W2W (Word to Word) · pendientes y estado

> Memoria del proyecto entre chats. **Léelo antes de empezar** y actualízalo al terminar.
> Lo mantiene al día la bitácora nocturna y el cierre de cada sesión.

_Última actualización: 2026-11-21_

## Estado actual
- **Servidor** Laravel en esta carpeta, publicado en `w2w.huergalabs.dev` por el túnel de Cloudflare (procesos en el panel).
- **App Android** (`mobile/`, Flutter): **1.0.14 (16)** en Play (prueba interna) con Shorebird; parches 1–3, **4** (15/11: protector de racha, informe semanal, recordatorio automático) **5** (loader al pensar), **6** («I heard» y consejos en Oído), **7** (nota por voz más tolerante) **8** (avisa «repeat/slower» para la escalera) **9** (registro con código de invitación) **10** (loader «Evaluando…» en errores para repasar) **11** (errores: «Dilo así:» con la frase correcta desde el principio) **12** (errores: tocar el micro para terminar, espera de silencio 1,1 s) **13** (mini-taller de la palabra que fallas) y **14** (manos libres: tocar la barra para terminar, consejos en paralelo), todos del 15/11; **15** (16/11: loaders de Taller/Sonido y Oído) **16** (16/11: shadowing de la unidad en la app) **17** (17/11: prueba de la unidad —conversación con nota— en la app) **18** (18/11: Brainy, la mascota) y **19** (18/11: cuidados de Brainy y Modo Brainy).
- Tests: servidor 280 ✓ (19/11), app 189 ✓ (+2 saltados), `flutter analyze` limpio (19/11). Último parche de Shorebird: **26** (19/11).
- Repasos con **FSRS** desde el 15/11 (`VOCAB_SRS=classic` en .env vuelve al sistema de saltos fijos).
- iPhone: web en pantalla de inicio y, desde el 15/11, **app nativa instalada con Xcode** en el iPhone Air (R3Y), firma del equipo PTJG6N43MX válida hasta 15/11/2027. Reinstalar: `flutter build ios --release` y `xcrun devicectl device install app --device <id> build/ios/iphoneos/Runner.app`. Sin notificaciones push de Apple (los avisos son locales). Se instala por wifi (el iPhone está emparejado en red local); no caduca a los 7 días: firma de pago hasta 15/11/2027.
- Voz: Whisper local en el Mac para el habla libre; Azure para la nota de pronunciación.
- **Publicación automática**: cambios en `main` de GitHub → tests → migrar (panel → «Publicación»). La app Android va por parche aparte.

## Funciones hechas (recientes)
- (21/11) **Por qué hoy no hay palabras nuevas** (Metodología (a)): `/session/today` manda `new_pause_at`; la web (Hoy clásico:
  «nuevas en pausa» y una nota) y la app (bajo «En la sesión») dicen «Hoy no hay palabras nuevas: tienes N repasos atrasados. Cuando
  bajen de 21, vuelven las nuevas.». En Modo Brainy (web) no sale. Commit `53a1ca7`, **parche 34**, `today.js?v=10`, caché v54.
- (21/11) **API sin sesión → 401 en JSON** (antes 500 «Route [login] not defined» sin cabecera Accept): `redirectGuestsTo` en
  `bootstrap/app.php`. Comprobado en vivo (401). Test en `SecurityRulesTest`.
- (21/11) **APK suelta** en iCloud (`W2W-1.0.14.apk`, código de hoy). Firmada con la clave de subida, no la de Play: no se instala
  encima de la versión de Play (hay que desinstalar antes) y **no recibe parches de Shorebird**. Se compila con el Flutter de
  Shorebird (`~/.shorebird/bin/cache/flutter/*/bin/flutter build apk --release`); el Flutter normal falla en el hook de `objective_c`
  (si pasa, borrar `mobile/.dart_tool/hooks_runner`).
- (20/11) **La web ya tiene lo mismo que la app** (pedido por Reynaldo: «Todo, Brainy completo»). Comparación hecha con un inventario
  de las dos (la web ya tenía MÁS: conversación libre, foto, chat, taller completo, recuperar contraseña). Lo que faltaba, hecho en 3 commits:
  1. `af4cce6` **Ajustes → «Qué aprendes»** (curso, solo si hay 2+) y **«Tu trabajo»** (profesión + para qué), tarjeta «¿A qué te dedicas?»
     en Hoy (`account.js`); **mini-taller de la palabra** en «errores para repasar», también por voz, con interruptor en Ajustes
     (`worddrill.js`, mismos umbrales que la app 60/70/2); **manos libres de errores aguanta un error suelto** (antes saltaba el error).
  2. `a691aea` **Brainy en la web**: `pet-draw.js` (dibujo y animaciones en canvas, portado por un agente: mismo cerebro de 680 neuronas,
     etapas, ánimos, formas, colores, nacimiento de 7 s) y `pet.js` (tarjeta en Hoy, pantalla de Brainy, Modo Brainy, botones de cuidado
     que abren el ejercicio, nacimiento con nombre y color, Ajustes → Brainy, experimento A/B como la app). Modo Brainy se guarda en el navegador.
  3. `896ff0a` **Avisos de Brainy en la web** por push del servidor: migración aditiva aprobada (`pets.web_alerts`, `web_alerted_at`,
     `web_alerts_today`; copia en `~/Backups/w2w/database-2026-11-20-antes-avisos-brainy-web.sqlite`) — **aplicada a mano el 20/11 21:40** (la publicación automática no migra los commits hechos en el Mac), `PUT /pet/alerts`, tarea `pet:alerts`
     cada 5 min (nunca 21:00–8:30, máx. 2/día, 3 h de separación, uno por ausencia). Interruptor solo con Modo Brainy.
  Tests: servidor 336 ✓ (+13: `WebAppParityTest`, `PetWebAlertsTest`). Probado en Chrome sin pantalla con la **demo** (sin errores de JS;
  capturas revisadas). La cuenta de pruebas no se pudo usar (el sistema de permisos no dejó crearle un acceso). **No probado en iPhone/Safari.**
- (20/11) **Correos «No se publicó: word-to-word»: arreglado** (`39a0dcc`). La publicación automática del panel prueba la app en una
  copia recién sacada de git, y `mobile/test/fonts/*.ttf` estaba en `.gitignore`: sin fuentes fallaban los tests de pantalla (15–26
  fallos) en CADA push desde el 19/11, y la marca de «publicado» se había quedado en `75df917`. Las fuentes (3 MB, licencia OFL) ya
  van en git. Comprobado: `hq:auto-deploy` → «Publicado 39a0dcc», 202 tests en la copia limpia.
- (20/11) **Web · «Revisa tu correo»**: al pedir el enlace de contraseña la pantalla de entrar se quedaba igual (solo una línea verde).
  Ahora cambia a una pantalla propia (sobre, a qué correo, «no hay ningún código que escribir», 60 min, spam, «Enviar otra vez»).
  El texto de ayuda decía 8 caracteres y son 10 con letras y números: corregido, y el campo lo exige al crear contraseña (entrar
  sigue aceptando las antiguas de 8). `app.js?v=23`, caché `wtw-shell-v49`, `WebAuthScreenTest`. Probado en Chrome sin pantalla.
  La cuenta de pruebas (id 2) pasó a `test@huergalabs.dev` y está en el curso de español; **tenía la contraseña por defecto de
  Laravel: Reynaldo debe cambiarla con «¿Olvidaste tu contraseña?»**. Sigue pendiente «Olvidé mi contraseña» en la app Android.
- (19/11) **Avisos de Brainy** (`dbafc6f`, **parche 28**): servidor `PetCare::state` → `care.alerts` = [{kind: hungry|bored, at}]
  (cuándo bajará cada barra a 1 corazón, saltando la noche; vacío si hiberna o está malita; sin migración). App:
  `core/services/brainy_alerts.dart` (`BrainyAlerts.plan`, ajuste `brainy_alerts`, `brainyAlertsSyncProvider` en `home_shell`),
  `ReminderService.syncBrainy` (canal Android `brainy_alerts`, ids 200–201; el recordatorio diario ya solo borra los suyos, 100–109).
  +2 tests servidor (285), +11 app (202).
- (19/11) **Prueba de micrófono en la web: `/prueba-micro`** (https://w2w.huergalabs.dev/prueba-micro). Para saber si un micrófono (el del carro por Bluetooth, audífonos…) sirve para practicar hablando. Graba 3 s de silencio + 7 s leyendo una frase y lo analiza **en el navegador** (no se envía ni se guarda nada en el servidor; la CSP no deja hacer peticiones): voz frente al ruido, hasta dónde llegan los agudos, distorsión y cortes; da nota Bueno/Regular/Malo, deja escucharse, guarda las pruebas en el teléfono para comparar y «Copiar resultados». Pública, sin cuenta, `noindex`, sin enlace desde la app. Archivos: `MicTestController`, `resources/views/mic-test.blade.php`, `public/mic-test.js`, `public/mic-test.css`; test `MicTestPageTest`. Servidor 283 tests. Probado: las cuentas con voz sintetizada (banda completa, tipo llamada, con ruido) y el flujo entero en Chrome con micrófono simulado. **No probado: en un iPhone/Android real ni con un carro.**
- (19/11) **Brainy: nacimiento nuevo** (pedido por Reynaldo: «en HD»). Commit `395a38f`, **parche 27**, iPhone reinstalado. Las 680 neuronas llegan en remolino cada una a su sitio del cerebro, se conectan y laten; tras el estallido el cuerpo sale de detrás de la cúpula, crece la antena, se enciende la chispa, abre los ojos y da un saltito. Vibración suave en cada golpe (no si se salta ni con «Reducir movimiento»). Dura 7 s; tocar la adelanta. Los tiempos están en `BirthTimeline` (pet_birth.dart) y la pose en `PetBirthPose` (pet_figure.dart). Decidido: se mejora en código, no con video ni Blender (un video sería archivo nuevo = versión de Play, y no encajaría con la mascota real). Sin sonido por ahora (exige versión nueva). Video de muestra: `~/Desktop/Brainy-pruebas/17-nacimiento-nuevo-HD.mp4`. App 191 tests. **No probado en teléfono real** (fluidez y vibración).
- (19/11) **Brainy: personaje nuevo** (elegido por Reynaldo tras muchas pruebas; para todos los alumnos). Commit `462b5b0`, **parche 26**
  (dry-run «No issues detected»), iPhone Air reinstalado (19/11).
  **Dibujo** (`pet_figure.dart`, misma API `PetFigure`/`PetPainter`: la tarjeta de Hoy, la pantalla de Brainy, el Modo Brainy y el
  nacimiento lo usan sin cambios): cuerpo del color elegido con degradado, ojos grandes con brillo, brazos, pies, antena con la chispa
  y una cúpula de cristal con el cerebro. Pensado en una hoja de 400 × 420 y escalado. Conserva TODO lo de antes: 5 etapas (nace
  pequeña y con ojos cerrados; brazos y pies desde «Aprendiz»; voz desde «Voz»; aura en la última), estados (hambre, aburrida,
  desorden, malita, dormida) y formas adultas (orejas, voz doble, gafas, estrella). Ya no tiene el brote verde.
  **Cerebro** (`pet_cloud.dart` → `BrainCloud`): nube de 680 neuronas en 3D vista desde un ángulo fijo (la receta del cerebro del
  panel, misma semilla) con sus conexiones. **Nace con todas las neuronas BLANCAS**; cada una tiene un umbral fijo y se enciende
  con el color de su zona cuando el nivel de esa zona lo supera (`PetPainter.regionOf`: camino, memoria, hábito, palabras, conexiones
  → regiones 0–4; niveles de `GET /api/pet`, sin cambios en el servidor). `BrainSignals`: 30 señales (12 en figuras pequeñas) que
  viajan de neurona en neurona; no gira. Se dibuja con `drawRawPoints` (pocas llamadas por cuadro). Con «Reducir movimiento», quieta.
  **Color:** `pets.color` (migración solo aditiva, **aplicada el 19/11**; copia en
  `~/Backups/w2w/database-2026-11-19-antes-color-mascota.sqlite`), lista fija `PetService::COLORS` = blue, purple, pink, coral, orange,
  green, teal (la misma en `BrainyColors.choices`; un test de la app la compara). `PUT /api/pet/color` (throttle 20/min; `null` = neutro).
  Sin elegir, la mascota es **gris neutro** (también las de alumnos de antes). Se elige en el nacimiento (paso 2, tras el nombre:
  `PetColorPicker`, cambia al momento) y en Ajustes → Brainy → «Color de tu mascota» (`PetColorDialog`).
  +4 tests servidor, +8 app. Revisado en una hoja con todos los estados y en capturas del nacimiento
  (`~/Desktop/Brainy-pruebas/15…` y `16…`); **no probado en un teléfono real** (fluidez, batería).
  Descartado en el camino (está en el historial de git, archivo `brainy_character.dart`): cerebro dibujado con surcos, cerebro 3D
  fiel al panel, cerebro como cabeza, personaje que gira 360° y las dos piezas separadas.
- (19/11) **Nacimiento de Brainy, segunda versión** (a Reynaldo la primera le pareció «vaga»): cielo con estrellas que parpadean,
  34 neuronas de colores que llegan en espiral y hacen crecer la chispa, tres latidos con anillos, estallido (destello, onda y chispas)
  y la mascota aparece con un rebote y destellos alrededor. 6,2 s; `_BirthPainter` y `_SkyPainter` en `pet_birth.dart` (todo con
  `CustomPainter`, números «al azar» fijos). Commit `ba72d6e`, **parche 25**, iPhone Air reinstalado. Revisada en un GIF hecho cuadro
  a cuadro; **no vista en un teléfono real**. Si aún se queda corta: opción Lottie o Rive (ver Decisiones).
- (19/11) **Brainy nace, le pones nombre y te avisa con su voz** (idea de Reynaldo; **para todos los alumnos**, no solo el grupo
  «brainy» del experimento). Commit `9c05cf1`, **parche 24** (dry-run «No issues detected»), iPhone Air reinstalado (19/11).
  **Servidor:** `pets.name` y `pets.welcomed_at` (migración solo aditiva, **aplicada el 19/11**; copia en
  `~/Backups/w2w/database-2026-11-19-antes-nombre-mascota.sqlite`). `GET /api/pet` añade `named` y `welcomed`; `PUT /api/pet/name`
  (throttle 10/min) guarda el nombre (2–20 letras, números, espacios, `-` y `'`; `PetService::NAME_RULE`) o, con `null`, apunta «luego».
  «Brainy» como nombre = volver al de siempre. Reiniciar progreso borra la mascota: vuelve a nacer.
  **App:** `pet_birth.dart` → `PetBirthPage`, a pantalla completa y **una sola vez** (la lanza `home_shell.dart` cuando
  `pet.welcomed == false`): una chispa aparece y late, un destello, y la mascota crece desde ella (4,2 s; tocar la adelanta; con
  «Reducir movimiento» sale ya formada). Pregunta «¿Cómo me quieres llamar?»; con nombre dice «¡Me llamo X! Tengo hambre de palabras.
  ¿Me enseñas la primera?» y «Empezar» cierra (vuelve a Hoy; **no abre el ejercicio directamente**). «Luego» = se queda como Brainy.
  Alumnos de antes (mascota ya crecida): misma animación con «¡Hola! Soy tu mascota.». Ajustes → Brainy → «Nombre de tu mascota»
  (`PetNameDialog`). Con servidor viejo no sale nada. **Avisos:** `ReminderService.messages(nombre)`: el recordatorio diario local lo
  dice la mascota («Luna tiene hambre de palabras»…), 4 textos sin culpa (hay test); sigue siendo UN aviso al día a la hora elegida.
  El aviso por web push (iPhone en la web) no cambió: la web no tiene Brainy. +8 tests servidor (`PetNameTest`), +16 app
  (`pet_birth_test.dart`). Revisado en imágenes de 4 momentos de la animación; **no probado en un teléfono real**.
- (19/11) **Ritmo de estudio** (tras revisar la metodología): (1) **Freno de palabras nuevas**: con MÁS de 20 repasos atrasados
  (`vocab.new_pause_reviews`, `VOCAB_NEW_PAUSE_REVIEWS`; 0 = sin freno) `SrsService::queue` no ofrece palabras nuevas hasta ponerse al
  día; `/api/today` y `/api/session/today` añaden `new_paused` y `reviews_due`. Brainy «Comer» manda a repasar. (2) **Reaprender el
  mismo día**: «Olvidé» deja la palabra pendiente para HOY (al final de la cola) en vez de mañana (`vocab.relearn_same_day`,
  `VOCAB_RELEARN_SAME_DAY=false` vuelve a mañana); acertarla el mismo día no sube la estabilidad FSRS. Web y app: el botón dice «hoy
  otra vez» (`days(0)`); `app.js` v22, caché del SW **v48**. Commit `97fed3b`, **parche 23**, iPhone Air reinstalado (19/11).
  +9 tests servidor (`StudyPacingTest`), +1 app. Efecto inmediato: la cuenta de Reynaldo (35 repasos atrasados) no recibe palabras
  nuevas hasta bajar a 20. **No probado en un teléfono real.**
- (19/11) **Android: opción «Micrófono de los audífonos»** (Ajustes → Audífonos), **apagada por defecto**. Encendida, la grabación
  usa el micrófono de los audífonos Bluetooth (`AndroidRecordConfig(manageBluetooth: true)`: los pone en modo llamada mientras grabas)
  para practicar con el teléfono guardado; a cambio la voz de la app suena con calidad de llamada y algunos audífonos quitan la
  cancelación de ruido. Apagada, todo como siempre. Sin audífonos la tarjeta sale apagada y en gris (la preferencia no se toca).
  `AppAudio.headsetMic()`, `headsetMicProvider`, `HeadsetMicCard`; +5 tests (`headset_mic_card_test.dart`). Sin permisos nuevos (la 1.0.14
  ya trae `BLUETOOTH_CONNECT` y `MODIFY_AUDIO_SETTINGS`) ni iconos. Commit `47860b4`, **parche 22** (dry-run «No issues detected»).
  **No probado en un teléfono real**: falta ver si cada marca cambia de modo a tiempo (puede perderse el principio de la frase).
- (19/11) **iPhone: «Micrófono de los AirPods» ya no sale activado sin audífonos** (Ajustes). Era solo la tarjeta: pintaba la
  preferencia guardada (encendida por defecto) sin mirar si había audífonos, y decía «Te oye por los AirPods». Ahora, sin audífonos
  (`headphonesProvider` = null), el interruptor sale apagado y en gris con «No hay audífonos conectados: ahora te oye el micrófono del
  iPhone…»; la preferencia no se toca y vuelve a verse al conectarlos. La grabación no cambió. `AirPodsMicCard` (antes privada) en
  `settings_page.dart`, +5 tests (`airpods_mic_card_test.dart`). La tarjeta solo existe en iPhone: **sin parche de Android**;
  iPhone Air reinstalado (19/11). No probado en el teléfono con y sin AirPods.
- (19/11) **Experimento A/B del Modo Brainy** — hecho y **APAGADO** (lo enciende Reynaldo en el `.env`). Commit `3d7cb3e`, **parche 21**
  (dry-run «No issues detected»). Tabla nueva `experiment_participants` (migración solo aditiva, **aplicada el 19/11**; copia previa en
  `~/Backups/w2w/database-2026-11-19-antes-experimento.sqlite`).
  **Grupos:** `BrainyExperiment::groupOf(id)` = `crc32("brainy-ab:" . id) % 2` → 1 = `brainy` (Modo Brainy encendido por defecto),
  0 = `control` (apagado, como hoy). En marcha solo si `BRAINY_AB_ENABLED=true` y `BRAINY_AB_START=AAAA-MM-DD` ya llegó
  (`config/experiments.php`). No entran la demo ni los ids de `BRAINY_AB_EXCLUDE_IDS` (por defecto `1`, la cuenta de Reynaldo).
  `GET /api/me` añade `brainy_default`: `true` / `false`, o `null` si no hay experimento. Con los usuarios de hoy: 5, 7 y 10 → brainy;
  2 y 40 → control; 1 excluido.
  **App:** `brainy_mode_setting.dart` — si el alumno nunca tocó el interruptor vale `brainy_default`; si lo tocó, manda su elección
  para siempre (en el teléfono solo hay algo guardado cuando lo tocó: eso es «lo cambió a mano»). `features/experiments/data/
  brainy_experiment.dart` informa con `POST /api/experiments/brainy` (`mode`, `changed`, `opened`; throttle 30/min) al entrar, al
  cambiar el modo y al abrir Brainy; si falla se ignora. Sin experimento (`null`) la app no envía nada y queda como antes.
  **Servidor:** guarda por alumno grupo, modo real, si lo cambió y cuándo, aperturas y botones de cuidado (`POST /api/pet/{acción}`).
  **Informe:** `php artisan experiments:report brainy` (`--json`) y bloque `experiments.brainy` en `metrics:snapshot`.
  +14 tests servidor (`BrainyExperimentTest`), +13 app (`brainy_experiment_test.dart`). **No probado en un teléfono real** ni con el
  experimento encendido en producción. **iPhone Air reinstalado (19/11)** con sugerencias y experimento.
- (19/11) **Sugerencias de usuarios** (servidor + web + app) y **página de apoyo voluntario** (solo web). Commit `e48c5bb`, **parche 20**
  (dry-run «No issues detected»).
  **Sugerencias:** tabla nueva `suggestions` (migración solo aditiva, **aplicada el 19/11**; copia previa en
  `~/Backups/w2w/database-2026-11-19-antes-sugerencias.sqlite`). `POST /api/suggestions` (`SuggestionController`): con sesión,
  `throttle:5,10`, tope de 10 al día por alumno y 500 entre todos (`Suggestion::DAILY_*`), `type` idea|bug|other y `platform`
  android|ios|web con lista fija, mensaje de 5 a 2000 letras, `user_id` y `status` siempre puestos por el servidor; la demo recibe 403.
  Se borran con la cuenta; «Reiniciar progreso» no las toca. `metrics:snapshot` añade el bloque `suggestions`
  (`new`, `new_by_type`, `last_7d`, `total`; solo cifras, nunca el texto). **Web:** «💡 Enviar sugerencia» en Ajustes
  (`public/app/feedback.js`, botones con `data-fb`, sin `onclick=`); `app.js` v21, caché del SW **v47**. **App:** Ajustes → «Tu opinión»
  → «Enviar sugerencia» (`features/feedback/`), envía sola la versión (`appVersion` en `core/config/env.dart`; un test avisa si no
  coincide con `pubspec.yaml`), la plataforma y la pantalla. Emoji en vez de icono nuevo. Al final de Ajustes: «W2W 1.0.14 · huergalabs.dev».
  **Apoyo:** `/apoyo` («☕ Apoya mi desarrollo con un café», es/en, `SupportController` + `resources/views/apoyo.blade.php`), sin scripts y
  con CSP propia. Datos del `.env`: `SUPPORT_ZELLE` y `SUPPORT_PAYPAL_URL` (solo https de paypal.me / paypal.com). **Hoy están vacíos:
  la página da 404 y el enlace no sale** hasta que Reynaldo los ponga. El enlace solo está en la web (Ajustes); un test del servidor y
  otro de la app fallan si la app Flutter menciona /apoyo, PayPal o Zelle. +15 tests servidor (`SuggestionTest`, `SupportPageTest`),
  +7 app (`feedback_test.dart`). Probado en Chrome sin pantalla contra un servidor de prueba (enviar sugerencia y ver /apoyo a 390 px);
  **no probado en un teléfono real**. iPhone Air reinstalado el 19/11.
- (18/11) **Brainy: cuidados tipo mascota virtual + Modo Brainy** (Pasos 6a+ y 6a++ de `~/Code/brain/HANDOFF.md`; solo en la app).
  **Servidor:** tabla nueva `pets` (migración solo aditiva, **aplicada el 18/11**; copia previa en
  `~/Backups/w2w/database-2026-11-18-antes-mascota.sqlite`). `PetCare` lleva 4 barras de 0–4 corazones: **comida** (palabra nueva +1,
  repaso +¼; pierde 1 cada 6 h despierta), **ánimo** (Oído, hablar, sonidos; pierde 1 cada 8 h), **limpieza** (no se guarda: son los
  repasos y errores pendientes; 0 / ≤5 / ≤15 / ≤30 / más → 4…0) y **salud** (enferma tras un día con hambre a cero o con el desorden a
  tope; se cura con el taller de un sonido o quitando la causa). De 22:00 a 07:00 duerme y no baja nada. **Nunca muere**: a los 5 días
  sin cuidados hiberna y despierta con el primer ejercicio. Los cuidados suben **solo al estudiar de verdad** (gancho en
  `XpService::add` → `petCare`), nunca por pulsar un botón. `GET /api/pet` añade el bloque `care`; `POST /api/pet/{feed|play|clean|medicine}`
  (lista fija) dice qué ejercicio toca. **La etapa ya nunca baja** (`stage_max`), se guarda su historia y su forma adulta según lo que
  más practicas (parlanchina / orejona / sabia / equilibrada, se fija al llegar a la última etapa). Reiniciar progreso o borrar la
  cuenta borra la mascota. Si la tabla fallara, los puntos y la mascota siguen (sin barras). Todo ajustable en `config/pet.php` → `care`.
  **App:** `pet_care_panel.dart` (barras de corazones dibujadas, botones Comer / Jugar / Limpiar / Medicina que abren los ejercicios de
  siempre: palabras nuevas, Oído, repasos, un sonido), `pet_actions.dart`, caras según el ánimo, globo con inglés fácil y «gracias» al
  volver, formas adultas e historia en la pantalla de Brainy. **Modo Brainy**: interruptor en Ajustes → Brainy, **apagado por defecto**,
  guardado en el teléfono (`brainy_mode_setting.dart`); encendido, la pestaña Hoy es Brainy (`pet_home.dart`) y «Mi sesión de hoy» abre
  la pantalla de siempre (`/today-classic`). Con servidor viejo o sin mascota sale Hoy normal. Sin imágenes ni iconos nuevos (los
  botones usan emoji, que es texto). Commit `1f8598d`, **parche 19** (dry-run «No issues detected»), **iPhone Air reinstalado (18/11)**.
  +18 tests servidor (`PetCareTest`), +23 app (`pet_care_test.dart`). Dibujo revisado en imágenes, **no en un teléfono real**.
- (18/11) **Brainy, la mascota que aprende lo que tú aprendes** (Paso 6a de `~/Code/brain/HANDOFF.md`; solo en la app, la web no la tiene).
  **Servidor:** `GET /api/pet` (`PetController`, `PetService`, `config/pet.php`), solo lectura y **sin tablas nuevas**: calcula con lo que
  ya hay. Puntos = palabras aprendidas ×1 + palabras bien recordadas ×2 (stability FSRS ≥ 21 días; las de antes de FSRS, por su nivel)
  + unidades del Camino ×8 + racha (tope 30). Cinco etapas por puntos (0, 15, 60, 180, 450): Chispa, Brote, Aprendiz, Voz, Mente
  brillante. Cada cosa enciende una zona del cerebro (palabras /300, memoria /150, Camino /12, hábito /30; «conexiones» = la media).
  **App:** `features/pet/` — tarjeta en Hoy (debajo de «Tus palabras») y pantalla `/pet`. Dibujada con `CustomPainter` (`pet_figure.dart`;
  el cerebro de neuronas es el del icono de Brainy portado a Dart, `pet_brain.dart`): **sin imágenes ni iconos nuevos**. Crece con la
  etapa (ojos, brote, brazos, voz, brillo), respira, parpadea y laten sus neuronas; con «Reducir movimiento» se queda quieta. Se
  refresca al terminar una sesión. Servidor viejo, error o sin datos → la tarjeta no sale y todo sigue igual; sin conexión enseña la
  última vista. Textos es/en en `lang/en.json` y `strings_en.dart`. Commit `826aa7f`, **parche 18** (dry-run «No issues detected»), **iPhone Air reinstalado (18/11)**.
  +8 tests servidor (`PetTest`), +19 app (`pet_test.dart`). Dibujo revisado en una imagen de las 5 etapas, **no en un teléfono real**.
- (17/11) **Prueba de la unidad en la app** (la "charla con un vecino"; antes solo en la web): el paso `test` del Camino es una conversación hablada con la IA en el escenario de la unidad (`/speaking/sessions` + `/conversation`), con corrección de cada mensaje; al terminar califica toda la charla (`/path/units/{id}/test`, ≥5 respuestas, aprueba ≥6/10) y marca el paso. Con manos libres (di "stop"). `conversation_controller.dart`/`conversation_exercise.dart`, `SessionRepository.startConversation/converse/unitTest`, `ConversationStep`, `PathUnit.scenario`. **La unidad del Camino se completa entera en la app.** Sin iconos nuevos. Commit `9c973a7`, **parche 17**, **iPhone reinstalado**. +6 tests. (El servidor ya tenía todo; solo Dart.)
- (17/11) **Manos libres aguanta un error suelto del servidor** (app, errores para repasar): si la nota falla por red o 5xx dice «Sorry, something went wrong. Try again.» y vuelve a escuchar; al 2.º seguido se pausa como antes; 401/422/429 no se reintentan. `HandsFreeController.server()` (sirve para otros ejercicios). Commit `8404a17`, +2 tests (app 93 ✓). **Parche**: no lo lancé yo; otra sesión estaba compilando uno a las 00:24 y probablemente lo incluye: comprobar el número y si salió después de `8404a17`.
- (17/11) **Arreglado «database is locked» (error de servidor en errores para repasar)**: la app pide la nota y los consejos A LA VEZ; las dos peticiones subían el contador diario (`DemoGuard` → `Cache::increment`) y SQLite, con transacciones `DEFERRED`, fallaba al instante sin esperar. Ahora `transaction_mode = IMMEDIATE` (`DB_TRANSACTION_MODE` en .env lo cambia). El 500 pausaba el manos libres: la app dejaba de grabar/hablar y los AirPods salían del modo llamada (parecía que se desconectaban). Commit `21870da`, +1 test (reproduce el choque). Solo servidor: sin parche.
- (16/11) **Shadowing de la unidad en la app** (antes solo en la web): el paso `shadow` del Camino se hace ya en Flutter (tras palabras y sonido). Carga el texto de la unidad, por frase Escuchar/Lento(🐢)/Ocultar, graba y Azure puntúa (palabra por palabra + nota/fluidez/precisión), pasa con ≥75% o 3 intentos y marca el paso con el promedio (`/path/units/{id}/shadow`, exige ≥60). Con manos libres. `shadowing_controller.dart`/`shadowing_exercise.dart`, `SessionRepository.shadowing/assessShadow/unitShadowDone`, `ShadowStep`. Sin iconos nuevos (parche seguro). Commit `b8b2b59`, **parche 16**, **iPhone reinstalado**. +5 tests. La *prueba* de la unidad y el shadowing de Practicar/Hoy siguen en la web.
- (16/11) **Evaluación en vivo sin esperas largas** (servidor): las 4 llamadas de IA que un alumno espera (conversación, narración, describir foto, calificar la prueba de unidad) ahora cortan a **~25s y SIN reintentos**; los lotes de noche (definiciones, etc.) siguen con 60s + reintento. El peor caso baja de **~180s a ~25s**. Interruptor `$live` en `ClaudeService::message`. +test `ClaudeLiveTest`. Commit `368bd87`.
- (16/11) **Loaders que faltaban** (web, con `368bd87`): al terminar una conversación, loader "Calificando tu conversación…" (antes la pantalla se quedaba congelada en "Te escucho…" durante la calificación, la llamada más lenta); y aviso "Evaluando…" en shadowing. `speak.js` v14, caché del SW **v46**.
- (16/11) **Loaders que faltaban** (app Flutter, **parche 15**): en Taller/Sonido ahora sale el loader "Evaluando…" y el micro deja de verse "Grabando" mientras el servidor puntúa (`sound_controller`/`sound_exercise`); en Oído–repetir se mantiene el aviso "Preparando cómo decirlo mejor…" en el tramo de consejos (`ear_exercise`). Commit `368bd87`; parche Shorebird 15 publicado (stable, 1.0.14+16); **iPhone Air reinstalado con Xcode (16/11)**.
- (16/11) **Contenido preparado sin IA** (escrito por Claude Code, no por el API): las 2.952 palabras ya tienen definición, definición fácil y frase larga (`database/content/words/*.json`, cargado con `php artisan words:content`, que solo rellena huecos y aplica las reglas de calidad). Banco de shadowing de 216 textos (6 niveles × 12 temas × 3, `database/content/shadowing.json`) y 3 escenas AID para las 500 palabras más comunes (`database/content/aids.json`): se usan primero y la IA solo si falta. Los trabajos `words:define`/`words:simplify` quedan sin nada que hacer salvo con palabras nuevas. Copia previa: `~/Backups/w2w/database-2026-11-16-antes-contenido.sqlite`.
- (16/11) **Manos libres**: tocar el círculo de la barra mientras escucha termina al instante; en errores, silencio 1,1 s y los consejos de Azure se piden a la vez que la nota. Parche 14.
- (15/11) **Mini-taller de la palabra que fallas** (app: errores para repasar y Oído-repetir, también manos libres): tras el 1.er intento fallido, si una palabra tiene nota Azure < 60 **y** no se entendió, se practica sola (2 intentos, nota ≥ 70), luego en su trozo de frase y se vuelve a la frase. Solo la peor palabra, una vez por frase; nunca se atasca. Interruptor en Ajustes → Pronunciación. `core/utils/word_drill.dart`, `core/widgets/word_drill_view.dart`. Parche 13, iPhone reinstalado. La web no lo tiene.
- (15/11) **Errores para repasar**: tocar el micro mientras graba termina al instante (sin esperar el silencio) y la espera de silencio bajó de 1,4 s a 1,1 s (app y web). Parche 12, iPhone reinstalado, `speak.js` v13, caché v45.
- (15/11) **Errores para repasar** muestran desde el principio «Dilo así:» + la frase correcta con botón de escuchar (antes solo salía al fallar); manos libres la lee despacio. App (parche 11, iPhone reinstalado) y web (`speak.js` v12, caché v44).
- (15/11) **Métricas de aprendizaje (Capa 2) para el panel**: `metrics:snapshot` añade el bloque `learning` sin tocar uso/retención: aciertos de Oído/Vocabulario/Hablar (7 días), las 5 palabras más falladas, racha media y protectores. La demo no cuenta. +2 tests (195 ✓). Commit `6f90c08`. El panel ya lo muestra en la tarjeta de W2W.
- (15/11) **Errores para repasar**: mientras el servidor evalúa la frase, loader de W2W en el centro con «Evaluando tu pronunciación…» y luego «Preparando cómo decirlo mejor…» (mic bloqueado). En la app (parche 10, también reinstalada en el iPhone) y en la web (`speak.js` v11, caché v43).
- (15/11) **Registro solo con código de invitación** (`invitation_codes`, `InviteService`, comando `php artisan invites list|create|disable`, JSON). Varios usos, caducidad opcional, desactivar; mismo mensaje para código malo/agotado/caducado. Campo en web (enlace `/app/?invite=CODIGO`) y app (la app Android ahora tiene pantalla «Crear cuenta»). `W2W_INVITE_REQUIRED=false` lo abre. Parche 9.
- (15/11) Escalera de español según la ESCUCHA: todos empiezan como mucho en el escalón 2 (la prueba de nivel mide leer). Sube al escalón del nivel si acierta ≥80 % en Oído (≥15 respuestas/7 días) y casi no pide repetir; baja uno si <60 % o ≥15 «repeat/slower». Datos en `listening_days` (`ListeningService`); app y web avisan con `POST /api/listening/help`. Parche 8.
- (15/11) Tests: `HUERGA_AI_KEY` vacía en phpunit.xml (con la clave en .env los tests llamaban al gateway de verdad).
- (15/11) Manos libres: cuando no te entiende, dice qué oyó («I heard: …»). En «¿Qué palabra oíste?», si se parece a una opción (beach≈peach) da el consejo de pronunciación de Azure y te la dice despacio.
- (15/11) Nota por voz más tolerante: acepta casi-iguales (east→easy, goo→good) y números (one=again … four=easy); al 2.º fallo lo recuerda. Parches 6 y 7.
- (15/11) Loader de W2W mientras la app «piensa»: manos libres (círculo) y narración («Revisando lo que dijiste…»). Parche 5 de Android e iPhone reinstalado.
- (15/11) iPhone: interruptor «Micrófono de los AirPods» en Ajustes (encendido por defecto): graba por los AirPods (HFP). La app es la única que configura el audio de iOS (`record` con `manageAudioSession(false)`); antes la grabadora lo cambiaba al grabar. Android sin cambios.
- (15/11) Protector de racha: salva un día sin estudiar; 1 nuevo cada 7 días de racha (máx. 2). Migración del 15/11 aplicada (solo columnas nuevas; copia previa en `~/Backups/w2w/`).
- (15/11) FSRS (`app/Services/Fsrs.php`): cada palabra guarda stability/difficulty; las viejas arrancan desde su nivel.
- (15/11) Recordatorio automático: hora habitual (mediana del primer XP, 21 días, mín. 3) + 30 min, y dice la palabra que toca.
- (15/11) Informe semanal de fluidez: `GET /api/speaking/weekly`, tarjeta «Tu semana hablando» en web y app.
- (15/11) `metrics:snapshot` cada hora → `storage/app/metrics.json`; el panel lo muestra en la tarjeta de W2W.
- (15/11) IA por el **gateway del panel** (agente `w2w`, solo Claude; clave «Word to Word» con límite 2000/día). Probado en vivo: escenas AID y conversación de 3 turnos. Si el panel cae, usa la clave directa; si llega al límite (429), no. Lotes > 8.000 letras van directo.
- Manos libres sin bucles: número de opción, nota hard/good/easy (también en español y con errores de oído) y sí/no; tras 3 fallos pide tocar la pantalla.
- Profesión y meta del alumno: escenarios y temas según su trabajo (12 profesiones; las de developer solo para «tech»).
- (13/11) Las traducciones que hace la IA sola (`i18n:translate`) ya no tocan `lang/en.json`: van a `storage/app/i18n/` (fuera de git), así no pausan la publicación. Para fijarlas en git: `php artisan i18n:promote` y commit.
- (13/11) App Android (parche 3): pestaña Ajustes (recordatorio, trabajo, español, AirPods, salir, borrar cuenta) y W2WLoader, barras de voz en vez de la rueda de Material. Tests de pantalla con la app de verdad gracias a `test/support/test_fonts.dart`.
- (13/11) Web: «Ajustes» es ahora la 5.ª pestaña de la barra de abajo (antes estaba al final de Progreso y no se encontraba).
- (13/11) Recordatorios en el iPhone: ya estaban hechos (web push desde la app instalada en pantalla de inicio); el 13/11 a las 19:00 salió uno.
- (13/11) Voz: Azure espera como mucho 8 s y, si falla, queda «caído» 1 minuto; la web corta a los 10 s y usa la voz del teléfono.
- (13/11) «Reiniciar progreso» pide la contraseña (salvo en la demo).
- (13/11) Web: app.js partido en handsfree.js, lab.js y boot.js (boot.js va el último). Guion de prueba con Chrome automático: ver git log.
- (13/11) App: tests del inicio de sesión (entrar, contraseña mal, token guardado, 401). Laravel 13.42; composer audit limpio.
- (13/11) SQLite con modo WAL y espera de 5 s: arregla los errores «database is locked».
- Recursos de la tienda: icono 512, gráfico 1024×500 y 4 capturas en `mobile/store/`.

## Pendiente (Reynaldo)
- [ ] Ver el aviso «Hoy no hay palabras nuevas» en Hoy (web clásica y Android tras abrir 2 veces, **parche 34**). Con tus ~49 repasos debería salir. No probado en teléfono real.
- [ ] Probar en el **iPhone (web en pantalla de inicio)**: Ajustes (curso, tu trabajo, Brainy), el nacimiento de Brainy, Modo Brainy y un
  botón de cuidado; un error para repasar diciendo mal una palabra (mini-taller). Activar «Avisos de Brainy» y ver que llega uno
  cuando tenga hambre (no de noche). Nada de esto se probó en un teléfono real (fluidez del dibujo en Safari incluida).
- [ ] **Probar el curso de español** con la cuenta `test@huergalabs.dev` (o la tuya: eres cuenta de prueba): Ajustes → «Qué aprendes» →
  Spanish for English speakers. Android: abrir 2 veces (parche 29). iPhone: instalar `W2W-iPhone.zip` de iCloud desde la MacBook.
  Apuntar lo que salga en inglés o roto. Antes: **cambiar la contraseña de esa cuenta** (tenía la de fábrica de Laravel) — quitar
  `test@huergalabs.dev` de la lista de bloqueo de Resend y usar «¿Olvidaste tu contraseña?».
- [ ] **Probar los avisos de Brainy** (Android: abrir la app 2 veces, **parche 28**; iPhone Air: instalado el 19/11 desde la
  MacBook). Encender Modo Brainy en Ajustes (pide permiso de
  notificaciones), dejar la app y esperar: debe llegar «<nombre> tiene hambre» o «<nombre> quiere jugar» a la hora en que baja a 1
  corazón. Fijarse en: si llega, si la hora tiene sentido, y si 2 avisos + el recordatorio diario son demasiados. **No probado en
  teléfono real** (solo tests). Se apagan en Ajustes → Brainy → «Avisos de Brainy».
- [ ] **Mirar la Brainy nueva en el teléfono** (Android: abrir 2 veces, parches 26 y 27; iPhone ya reinstalado). Al entrar sale el nacimiento Fijarse también en el **nacimiento nuevo**: si va fluido y si la vibración se nota bien.
  (tu cuenta aún no lo ha visto): nombre y luego color. Fijarse en: si va fluida (el cerebro tiene 680 neuronas animadas), si calienta
  o gasta batería, si en la tarjeta de Hoy se distingue, y si las neuronas encendidas corresponden a lo que llevas aprendido.
- [ ] **Ver nacer a Brainy y ponerle nombre**: al abrir la app (Android: 2 veces, parche 24; iPhone ya reinstalado) debe salir la
  animación una sola vez. Fijarse en: si la animación se ve fluida, si el teclado tapa el botón, y que mañana el recordatorio llegue
  con el nombre que le pusiste. Para volver a verla: «Reiniciar progreso» la borra (¡borra también tu progreso!); mejor pedir a Claude
  que ponga `welcomed_at` a null en tu fila de `pets`.
- [ ] Android (parche 22, abrir la app 2 veces): con audífonos Bluetooth, **Ajustes → Audífonos → Micrófono de los audífonos**.
  Encenderlo, guardar el teléfono y hacer un ejercicio de hablar. Fijarse en: si te entiende desde el principio de la frase, cuánto
  baja la calidad de la voz y si se quita la cancelación de ruido. Si va mal, dejarlo apagado (así viene) y avisar.
- [ ] iPhone: abrir Ajustes **sin** AirPods (el interruptor «Micrófono de los AirPods» debe salir apagado y en gris) y luego **con**
  AirPods (debe salir como lo dejaste y poder cambiarse).
- [ ] **Encender el experimento del Modo Brainy** cuando quieras empezar: añadir al `.env` de W2W
  `BRAINY_AB_ENABLED=true` y `BRAINY_AB_START=AAAA-MM-DD` (el día que empieza). Opcional: `BRAINY_AB_EXCLUDE_IDS=1,2` para dejar
  fuera también la cuenta de pruebas (id 2). No hace falta reiniciar. Para pararlo: `BRAINY_AB_ENABLED=false` (quien ya eligió a mano
  conserva su elección; el resto vuelve a apagado). Ojo: al encenderlo, la mitad de los alumnos que nunca tocaron el interruptor verán
  a Brainy como pantalla principal en la app Android (parche 21).
- [ ] **Revisar el informe a las 2–3 semanas de encenderlo** (no antes de 14 días): `cd ~/Code/word-to-word && php artisan
  experiments:report brainy`. Cómo leerlo: (1) mira primero el aviso de arriba; si dice «muy pocos alumnos» (menos de 20 por grupo,
  `BRAINY_AB_MIN_USERS`) las diferencias pueden ser casualidad y **no se decide nada**. (2) Las métricas que mandan son **PRÁCTICA
  REAL** (sesiones, ejercicios, palabras nuevas, repasos, Oído, minutos hablando; todo por alumno y semana) y **APRENDIZAJE** (aciertos
  y palabras bien recordadas). (3) Retención: «activos el día 7» = de los que ya cumplieron 7 días dentro, cuántos practicaron ese día.
  (4) «Uso de Brainy» es solo contexto: el grupo Brainy la ve al abrir la app, así que siempre tendrá más aperturas. (5) Si muchos del
  grupo Brainy lo apagaron a mano, es señal en contra aunque practiquen igual. **Hoy hay 6 usuarios (5 cuentan): el aviso de «muy
  pocos» va a salir seguro**; el experimento sirve de verdad cuando haya más alumnos con la app.
- [ ] **Apoyo:** poner en el `.env` de W2W `SUPPORT_ZELLE=` (tu correo o teléfono de Zelle) y `SUPPORT_PAYPAL_URL=` (p. ej.
  `https://paypal.me/tuusuario`). Sin eso `/apoyo` da 404 y el enlace no aparece en Ajustes de la web. No hace falta reiniciar.
- [ ] Probar **«Enviar sugerencia»**: en la web (Ajustes) y en la app Android (abrirla 2 veces para bajar el **parche 20**; Ajustes →
  Tu opinión). Para leer lo que llega, de momento: `sqlite3 database/database.sqlite "select created_at,type,platform,message from suggestions order by id desc"`.
- [ ] Probar a **Brainy con cuidados**: Hoy → tarjeta «Brainy» → ver las 4 barras de corazones y pulsar Comer / Jugar / Limpiar /
  Medicina (cada uno abre un ejercicio; al terminarlo, Brainy da las gracias y sube la barra). Luego **Ajustes → Brainy → Modo Brainy**:
  la pestaña Hoy pasa a ser Brainy y «Mi sesión de hoy» abre lo de siempre. Fijarse en: que los emoji de los botones se ven bien, que
  las caras se entienden (hambre, desorden, dormida de noche) y si el ritmo de las barras es bueno o agobia. Android: abrir la app 2
  veces (parche 19). Tienes ~49 repasos pendientes: Brainy nace «desordenada» y, si no bajan de 30 en un día, se pone malita (se cura
  con Medicina o limpiando).
- [ ] Probar la **prueba de la unidad en la app** (la charla con un vecino): Camino → una unidad con palabras, sonido y shadowing hechos → «Continuar la unidad» abre la conversación. Hablar ≥5 veces, pulsar «Terminar y evaluar» y ver la nota /10. Parche 17 (abrir la app 2 veces en Android) e iPhone ya reinstalado. Con esto una unidad se completa **entera** en la app. No probado en teléfono real.
- [ ] Volver a usar «errores para repasar» con manos libres y AirPods y confirmar que ya no sale el error de servidor (arreglo del 17/11, no probado en teléfono real).
- [ ] Probar el **shadowing de la unidad en la app** (Camino → una unidad con palabras y sonido ya hechos → «Continuar la unidad» abre el paso shadow): escuchar, repetir, ver las palabras en verde/rojo y que al terminar marque el paso. Parche 16 (abrir la app 2 veces en Android) e iPhone ya reinstalado. No probado en teléfono real.
- [ ] Ver los loaders de Taller/Sonido y Oído en un teléfono real (no probado aún): en Android, abrir la app 2 veces para bajar el **parche 15**; el **iPhone Air ya está reinstalado (16/11)** con ellos, solo abrir y mirar.
- [ ] Probar el mini-taller en el iPhone: decir mal una palabra en «errores para repasar» (no probado en teléfono real).
- [ ] Probar «Practicar → errores para repasar» en el iPhone y ver el loader «Evaluando…» (no probado en teléfono real).
- [ ] Crear el primer código en el panel (W2W → Invitaciones) y probar el registro en la web y en la app con el enlace `/app/?invite=…`.
- [ ] Probar en el iPhone Air con los AirPods puestos y el iPhone en el bolsillo (conversación y manos libres). No probado aún.
- [ ] Mirar la app nativa en el iPhone Air (instalada el 15/11): Progreso, Ajustes y un recordatorio.
- [ ] Abrir la app Android 2 veces para que baje el parche 4 y mirar Progreso y Ajustes (no probado en teléfono real).
- [ ] Confirmar que al iPhone le llegó el recordatorio de las 19:00 del 13/11 (el servidor lo envió sin error).
- [ ] Decidir si borrar `_to_delete/` (2 copias viejas de index.html del 31/10, fuera de git).
- [ ] Abrir la app Android 2 veces para que baje el parche 3 y mirar la pestaña Ajustes y el nuevo «cargando» (no probado en teléfono real).
- [ ] Completar la ficha de Play con el icono, el gráfico, las capturas y las descripciones (corta y completa).

## Pendiente (código)
- [ ] **Idea de Reynaldo (19/11): W2W como núcleo con cursos** — una sola app y al registrarse se elige qué idioma aprender; el
  primero nuevo sería **español para angloparlantes** (compañeros de trabajo americanos de Reynaldo como primeros alumnos). Es
  proyecto de aprendizaje: se hace por pasos aunque no haya demanda medida. **Nada empezado.** Mapa del 19/11 (solo lectura):
  · *Base de datos*: `words` no lleva idioma (columnas `word`, `translation`, `example`, `example_es`, `definition`…) y `user_words`,
    `speaking_mistakes`, `phoneme_errors`, `unit_progress`, `level_results`, `study_days` no llevan curso; `users.cefr_level` es uno solo.
  · *Contenido*: 2.952 palabras (NGSL + `database/data/*_words.php`), `config/units.php`, `config/professions.php`, banco de shadowing.
  · *Código con el inglés dentro*: `ClaudeService` (los textos que se piden a la IA, lo más grande), `StudyController`,
    `TtsService`/`PronunciationService`/`SpeakingController` (voz y evaluación en en-US), `config/speaking.php`, taller de sonidos.
  · *Ya existe y ayuda*: la pantalla traducida al inglés (app y web), y `SpanishService`/`spanish_step` («cuánto español de apoyo»).
  · *App Flutter*: 17 archivos mencionan inglés.
  **Paso 2a hecho y APLICADO (19/11 23:33 ET, con OK de Reynaldo; copia `storage/app/backups/w2w-2026-11-20_043320.sqlite.gz`):** `2026_11_20_000001_create_courses` crea `courses`
  (nace con el curso 1 `en-es`), añade `words.course_id` y `users.course_id` (por defecto 1) y cambia la palabra única por
  (curso, palabra). Solo añade; se puede deshacer (hay test). Ensayada sobre una copia de la base real: 2.952 palabras y 7 alumnos al
  curso 1, 83 progresos intactos, 6 ms; en la real salió igual. Modelo `Course`, `CourseTest` (5). Para deshacer: `php artisan
  migrate:rollback --step=1`. **Siguiente, paso 2b:** que las consultas de palabras filtren por el curso del alumno (~26 archivos).
  **Paso 2b hecho (19/11):** `App\Support\CurrentCourse` (el curso del alumno de la petición; sin alumno, el 1; `run($id, fn)` para
  que un comando trabaje con otro) + **regla global en `Word`**: toda búsqueda de palabras ve solo el curso actual y una palabra nueva
  nace en él (`Word::withoutGlobalScope('course')` para mirar todos). Cubre también las rutas `/words/{word}/…` (otra de otro curso =
  404). `CourseScopeTest` (5): un alumno de inglés no ve palabras de otro curso en 11 pantallas ni por id. **Sin cubrir a propósito
  (para el paso 5):** el progreso (`user_words`, errores, niveles, unidades) aún no va por curso, y los `join('words')` a mano
  (`StudyController::families`, `MetricsSnapshot`) no pasan por la regla; las tareas que recorren alumnos (recordatorios) usan el
  curso 1 y habrá que envolverlas en `CurrentCourse::run` cuando haya alumnos en otro curso.
  **Paso 3a hecho (19/11):** la evaluación de pronunciación y la transcripción (Azure y Whisper) usan `courses.speech_locale` del
  curso del alumno (`CurrentCourse::speechLocale()`) en vez de «en-US» fijo. Para el curso 1 no cambia nada. **3b hecho:** `TtsService` lee más despacio el idioma que se
  aprende en el curso (antes: «inglés» fijo). **3c hecho:** `App\Support\CoursePack::get('speaking.scenarios')` lee el CONTENIDO
  (conversaciones, temas, tipos de error, banco de shadowing, unidades, profesiones) del paquete del curso en `config/courses.php`
  (solo lo que cambia; lo demás se hereda de los archivos de siempre); 29 lecturas pasadas y un test que vigila que nadie lo pida con
  `config()` a secas. Las REGLAS del motor (metas, tiempos, umbrales) siguen en `config()`. **Falta del paso 3:** (3d) los textos que
  se piden a la IA en `ClaudeService` (~47 menciones de inglés/español; mejor hacerlo junto con el curso mínimo de español, para
  probar con respuestas de verdad); (3e) el taller de sonidos (lista de sonidos del inglés); (3f) el parámetro `lang=en|es` de la API
  debería ser `learn|from` (toca la app: parche); (3g) `config/spanish.php` y `SpanishService` = «idioma de apoyo», hoy con nombre de español.
  **Paso 4 empezado (20/11): curso `es-en` «Spanish for English speakers», APAGADO, con 60 palabras.** Decidido por Reynaldo: se
  diseña **igual que el de inglés** (palabras por frecuencia y nivel —A1 = 500—, 9 datos por palabra, familias, unidades,
  conversaciones). Ficha en `config/courses.php` (`es-en.course`); contenido en `database/content/courses/es-en/words/part*.json`
  (escrito a mano, sin IA); se carga con `php artisan courses:load es-en [--dry-run]` (repetible: actualiza, no duplica; solo cursos
  de la lista fija; `LoadCourseTest` vigila que cada ficha esté completa). En la base real: curso 2, 60 palabras (20 nombres y 40
  verbos muy comunes), 0 alumnos; un alumno de inglés no las ve. En esta tabla, para el curso de español, `translation` y
  `example_es` van en INGLÉS (el nombre de la columna `example_es` es herencia: significa «ejemplo en el idioma del alumno»).
  **Shadowing propio (20/11):** `database/content/courses/es-en/shadowing.json` (A1: 12 textos, uno por tema, 60 frases en español,
  escritos a mano). La clase del curso de español solo usa shadowing (`speaking.session_modes` en su paquete): narración, imagen y
  conversación siguen con instrucciones de IA para inglés. `ShadowingBank::sentencePattern()` y las dos validaciones de
  pronunciación aceptan acentos, ñ, ¿ y ¡ fuera del curso de inglés. Reynaldo lo vio en el iPhone: tras 3 palabras en español, la
  clase le pedía repetir frases en inglés.
  **Pasos de la clase por curso (20/11, parche 31; iPhone `W2W-iPhone-0148.zip` en iCloud):** `/session/today` manda `plan.steps`
  (del paquete: `session.steps`; null = todos). La app (`SessionPlan.fromToday`, `TodayData.has`) se salta «sound» y «narrate» si el
  curso no los tiene y habla con `ShadowStep`. Motivo: Reynaldo vio en el iPhone «Pronunciation: the sound /θ/ — think» en la clase
  de español: el taller de sonidos (`soundWords`) y la narración viven en la app y son del inglés. La pantalla Practicar aún ofrece
  los sonidos del inglés en cualquier curso.
  **Textos del servidor en el idioma del alumno (20/11):** `App\Support\Ui::t('…:n…', [...])` traduce con `lang/en.json` cuando el
  idioma propio del curso no es el español (en el curso de inglés no cambia nada). Pasados por él: nombre del nivel y «lo que
  puedes hacer», logros, tareas de «qué hacer hoy» (con huecos `:n`) y etiquetas de tipos de error. +44 traducciones escritas a
  mano; un test exige traducción para todos. La narración ya no se propone en «qué hacer hoy» si el curso no la tiene. Motivo:
  Reynaldo vio textos en español en Progreso con la pantalla en inglés. **Quedan en español** (vienen del paquete del curso de
  inglés): conversaciones, profesiones, familias y unidades; y los correos (verificación, contraseña).
  **Falta del paso 4:** las otras ~440 palabras de A1 (días, números, palabras gramaticales, familias), unidades y conversaciones del
  curso, y probarlo de verdad con una cuenta de prueba en el curso 2 (hoy solo se puede poner a mano: `users.course_id`).
  **Paso 5 empezado (20/11): elegir curso en Ajustes.** Servidor: `GET /api/courses` y `PUT /api/course {code}` (`CourseController`):
  solo cursos activos; los apagados solo los ven las cuentas de `vocab.course_testers` (`COURSE_TESTERS`, por defecto ids 1 y 2);
  `/me` trae `course`. **Progreso por curso**: regla global en `UserWord` (apoyada en la de `Word`): cambiar de curso no borra ni
  mezcla; «Reiniciar progreso» sí borra el de todos. App: `settings/presentation/course_card.dart` (Ajustes → «Qué aprendes», arriba;
  solo sale con ≥ 2 cursos), **parche 29**; iPhone: zip en iCloud Drive (`W2W-iPhone.zip`) para instalar desde la MacBook.
  `CourseChoiceTest` (5), +2 en `CourseScopeTest`, `course_card_test.dart` (5). **Parche 30 (20/11):** la app ya hace caso a `spanish.ui` del
  servidor (antes decidía el idioma de la pantalla solo por el escalón: en el curso de español seguía todo en español) y refresca el
  perfil al cambiar de curso. iPhone: `W2W-iPhone-0135.zip` en iCloud Drive. **Paso 5 hecho (20/11):** elegir curso al REGISTRARSE
  en app y web (84607db servidor, 96b3cd0 app/web; **parche 33**). Falta: el nivel (`users.cefr_level`), los errores al hablar, los sonidos, las unidades y los exámenes aún son uno solo
  por alumno, no por curso; la racha, los puntos y Brainy son comunes a todos los cursos (a propósito, por ahora).
  Pasos propuestos: (1) mapa ✅ · (2) tabla de cursos + curso en palabras y progreso (migración: OK de Reynaldo y copia) · (3) sacar
  el inglés a configuración · (4) curso de español mínimo (50–100 palabras + conversación, mejor con frases de su trabajo) · (5) elegir
  curso al registrarse · (6) verbos y sonidos del español. Los pasos 2–3 no cambian nada a la vista.
- [ ] Avisos de Brainy · siguientes: no avisa de desorden ni de «malita» (dependen de los repasos, no solo del reloj); el aviso
  no abre directamente el cuidado (abre la app); la web (iPhone sin app nativa) no tiene Brainy ni estos avisos. Las horas de noche
  del servidor usan `vocab.timezone` (Nueva York) y no la zona del alumno; la app sí aplica la hora local (nada entre 21:00 y 08:00).
  Ojo con el experimento A/B: los avisos pasan a ser parte de lo que recibe el grupo Brainy.
- [ ] Brainy nueva: medir en teléfono real y, si va justa, bajar neuronas (`BrainCloud._(680)`) o señales. Diseño de Figma de
  referencia: https://www.figma.com/design/e7DC7WFNKeuX5obmXOZ1ze (hoja «Brainy · personaje nuevo»).
- [ ] Brainy en el flujo (siguiente de la idea de Reynaldo): que reaccione al terminar la sesión (resumen con ella) y, con cuidado de
  no frenar el ritmo, tras cada ejercicio. Y que «Empezar» de la bienvenida abra directamente el primer ejercicio.
- [ ] **Metodología (revisión del 19/11):** el diseño es correcto (FSRS-4.5 bien implementado, recordar activo, Oído, shadowing, errores
  propios espaciados) pero **no hay datos para decir que funciona**: solo un alumno activo (Reynaldo, 8 días; 85 % de aciertos en
  repasos). Falta: (a) ~~decir por qué hoy no hay palabras nuevas~~ hecho el 21/11; (b) **hablar apenas se usa** (1 minuto en 9 días con meta de 5 al día; 2 sesiones guiadas completas): replantear la
  sesión para que hablar sea el centro y medir minutos reales — pensarlo con Reynaldo; (c) más alumnos antes de juzgar el método.
- [ ] Experimento Brainy: el panel recibe `experiments.brainy` en `metrics.json` pero aún no lo pinta. Límites conocidos del informe:
  los repasos y ejercicios salen de los puntos del día (`xp_days.by_source`), que tienen tope diario (100 repasos buenos); «palabras bien
  recordadas» cuenta todas las del alumno, no solo las de después de entrar; solo cuentan alumnos cuya app informó (la web no tiene Brainy).
- [ ] Sugerencias: **verlas y cambiar su estado** (new → reviewing → done / dismissed). Hoy solo se guardan; el panel recibe el conteo
  en `metrics.json` (bloque `suggestions`) pero aún no lo pinta ni hay pantalla para leerlas. Sin capturas de pantalla (decidido).
- [ ] Brainy · ajustar con datos reales: los puntos, metas y ritmos de `config/pet.php` están puestos a ojo (horas por corazón, cuánto
  da cada cosa, topes de desorden). Sin hacer del diseño del HANDOFF: **avisos locales** de Brainy (máx. 2 al día, nunca de noche; no
  añadí ninguno), frases con solo palabras ya aprendidas (hoy son 6 frases fijas de inglés muy fácil), árbol de evolución con dibujo
  (hoy es una lista con fechas). Sigue el **Paso 6b** («Enséñale una palabra»).
- [ ] (opcional) Usar `hf.server()` en los demás ejercicios de manos libres (Oído, Sonido, shadowing, narración) para que un error suelto tampoco los pause.
- Palabras nuevas que se añadan: escribir su contenido con Claude Code y `words:content` (si no, las rellena el API de noche como antes).
- [ ] La pestaña Hoy de la app no muestra el protector (`/session/today` no lo trae); solo Progreso.
- [ ] (opcional) Seguir partiendo `public/app/app.js` (~1100 líneas): niveles, conversación.
- [ ] (opcional) Cloudflare mete su script de estadísticas (beacon) y la CSP lo bloquea: apagar «Web Analytics» automático en Cloudflare para W2W o dejarlo así (no rompe nada).
- [ ] **Idea a futuro: W2W en el carro (CarPlay / Android Auto).** Decidido (19/11): ahora NO; es código nativo en los dos sistemas (versión nueva, no parche), solo admiten ciertas categorías (W2W entraría como «audio»; «educación» no existe), la pantalla es de ellos (sin Brainy ni ejercicios) y el micrófono para evaluar el habla es dudoso. Con ~5 alumnos no compensa. Pasos, en orden: (1) Reynaldo prueba el **modo manos libres por Bluetooth en un carro real** (¿sale por las bocinas?, ¿el micrófono del carro entiende?) — sin código; usar la página `/prueba-micro` (una prueba con el teléfono solo y otra con el carro, y pasarle a Claude lo de «Copiar resultados»); (2) controles en pantalla de bloqueo y volante (pausa/siguiente): cambio nativo pequeño y base de lo siguiente; (3) CarPlay y Android Auto de verdad cuando haya más alumnos y alguno lo pida. En el carro, solo escuchar y repetir (nada que obligue a mirar o tocar). **Por verificar antes de decidir:** si Apple abrió CarPlay a apps de conversación por voz (encajaría mejor que «audio»).

## Decisiones
- (20/11) Web = app: Brainy completo también en la web. Los avisos de Brainy en la web los manda el servidor (la web no puede programar
  avisos locales); se guardan en `pets` (migración aditiva aprobada por Reynaldo).
- (19/11) **Actualizar el iPhone fuera de casa**: la app compilada en el iMac ya va firmada para el iPhone, así que se instala desde
  cualquier Mac con Xcode: `ditto -c -k --keepParent build/ios/iphoneos/Runner.app W2W-iPhone.zip` → iCloud Drive → en la MacBook,
  iPhone por cable y `xcrun devicectl device install app --device <UDID> <ruta a Runner.app>` (arrastrar el archivo a Terminal para
  la ruta). Probado el 19/11. TestFlight + Shorebird sigue siendo la opción para que llegue solo.
- (19/11) **Brainy SÍ manda avisos, solo en Modo Brainy** (cambia lo del 18/11 «no manda avisos»): locales (sin Firebase, por
  parche), cuando va a tener hambre o va a querer jugar; máx. 2 programados, separados ≥ 3 h, nunca entre 21:00 y 08:00, nunca con
  culpa (hay test de palabras prohibidas). Interruptor propio, encendido por defecto. Push de servidor (Firebase) descartado por ahora:
  es cambio nativo y versión nueva en Play.
- (19/11) **CarPlay / Android Auto: ahora no.** Primero probar manos libres por Bluetooth en un carro; ver «Pendiente (código)».
- (19/11) Brainy es el personaje con cúpula y cerebro de neuronas dentro (no un cerebro con patas, ni cabeza-cerebro, ni 3D que gira).
  Nace neutra y con las neuronas blancas; el color lo elige cada alumno y las neuronas se encienden al aprender. Rive quedó
  descartado por ahora (su MCP pide plan de pago y el motor obliga a versión nueva en Play).
- (19/11) Animaciones de Brainy: por ahora con código (sin archivos nuevos → parche). Para más calidad: **Lottie** (After Effects o
  LottieFiles → JSON; el paquete `lottie` de Flutter parece ser solo Dart, **por comprobar**) o **Rive** (el mejor para mascotas
  interactivas, pero su motor es nativo → versión nueva en Play). Un archivo de animación nuevo es un asset: no cabe en un parche
  salvo que se baje del servidor.
- (19/11) Cada alumno nombra a su mascota; «Brainy» sigue siendo la marca y el nombre por defecto. El nacimiento y los avisos con su
  voz son **para todos** (aunque eso acerque los dos grupos del experimento A/B: con tan pocos alumnos no iba a concluir pronto).
  El nombre solo lo ve su dueño (si algún día sale en la liga, habrá que filtrar palabras).
- (19/11) Primero ponerse al día, luego palabras nuevas (freno a los 20 repasos atrasados). Lo que se olvida se reaprende el mismo día.
- (19/11) Si Brainy gana protagonismo se decide con datos: experimento A/B con «práctica real» y «aprendizaje» como métricas
  principales, no los clics en Brainy. El alumno siempre puede cambiar el modo y su elección se respeta.
- (19/11) Apoyo voluntario: se llama «apoyo», nunca «donación»; Zelle (EE. UU.) y PayPal (resto del mundo); **solo en la web**. En la
  app Android no se enlaza ni se mencionan pagos (política de Google Play); como mucho, el texto neutro «huergalabs.dev».
- (19/11) Sugerencias sin capturas de pantalla por ahora.
- (18/11) Brainy (mascota): diseño propio dibujado con código; todo se calcula en el servidor. Con los cuidados (6a+) ya tiene estados
  (hambre, desorden, malita, dormida), pero **nunca muere, no culpa ni dramatiza** y no manda avisos. Cuidarla = estudiar: los botones
  no dan nada, lo da el ejercicio. La etapa nunca baja. Modo Brainy apagado por defecto y sin quitar nada de la app normal.
- (15/11) No usar Claude Code como IA en vivo para los alumnos (términos de uso, lentitud, seguridad). Sí para preparar contenido de antemano.
- (16/11) Shadowing portado a la app **solo para la unidad del Camino** (lo que pidió Reynaldo). El shadowing de Practicar/Hoy sigue en la web por ahora.
- (17/11) Prueba de la unidad (conversación) portada a la app: la unidad del Camino se completa entera en Flutter. La *Conversación* libre de Practicar y el *Describe la imagen* siguen en la web.
- (16/11) Reafirmado: un **agente/suscripción de Claude como backend de los alumnos = no** (términos de uso + lentitud). Si el objetivo es **cero coste de API**, el sustituto real es un **modelo local en el Mac** (como Whisper/TTS) para la evaluación dinámica, + seguir ampliando el contenido precocinado. **Pendiente**: prueba de un modelo local comparando calidad/tiempo contra Claude antes de decidir. Mientras, el API ya está acotado (2000/día) y en vivo corta a ~25s.
- (15/11) Mini-taller de palabra: al terminar la frase, nunca a mitad; en conversación/narración, no se interrumpe.
- (15/11) Registro por invitación: códigos de varios usos con límite, creados por Reynaldo desde el panel.
- (15/11) La escalera de español tiene en cuenta cómo entiende el alumno al oír, no solo la prueba de nivel.
- (15/11) Prioridad: que la gente vuelva y medirlo antes que añadir funciones. MySQL cuando haya ~100 usuarios activos.
- (15/11) FSRS activado para todos, con interruptor para volver al clásico. Gateway de IA sí (cuando exista la clave).
- (15/11) iPhone: app nativa instalada con Xcode (además de la web).
- Parches de Shorebird: solo iconos de Material que ya estaban en la versión de Play (la fuente de iconos va recortada). Un icono nuevo = versión nueva en Play, o elegir uno que ya se use.
- Estilo Duolingo: sesión diaria guiada, camino por unidades, XP; enfoque en hablar con fluidez.
- Abierto a otros usuarios, no solo para Reynaldo.
- Nombre visible: W2W.
