# W2W (Word to Word) · pendientes y estado

> Memoria del proyecto entre chats. **Léelo antes de empezar** y actualízalo al terminar.
> Lo mantiene al día la bitácora nocturna y el cierre de cada sesión.

_Última actualización: 2026-11-19_

## Estado actual
- **Servidor** Laravel en esta carpeta, publicado en `w2w.huergalabs.dev` por el túnel de Cloudflare (procesos en el panel).
- **App Android** (`mobile/`, Flutter): **1.0.14 (16)** en Play (prueba interna) con Shorebird; parches 1–3, **4** (15/11: protector de racha, informe semanal, recordatorio automático) **5** (loader al pensar), **6** («I heard» y consejos en Oído), **7** (nota por voz más tolerante) **8** (avisa «repeat/slower» para la escalera) **9** (registro con código de invitación) **10** (loader «Evaluando…» en errores para repasar) **11** (errores: «Dilo así:» con la frase correcta desde el principio) **12** (errores: tocar el micro para terminar, espera de silencio 1,1 s) **13** (mini-taller de la palabra que fallas) y **14** (manos libres: tocar la barra para terminar, consejos en paralelo), todos del 15/11; **15** (16/11: loaders de Taller/Sonido y Oído) **16** (16/11: shadowing de la unidad en la app) **17** (17/11: prueba de la unidad —conversación con nota— en la app) **18** (18/11: Brainy, la mascota) y **19** (18/11: cuidados de Brainy y Modo Brainy).
- Tests: servidor 259 ✓ (19/11), app 160 ✓ (+2 saltados), `flutter analyze` limpio (19/11). Último parche de Shorebird: **21** (19/11).
- Repasos con **FSRS** desde el 15/11 (`VOCAB_SRS=classic` en .env vuelve al sistema de saltos fijos).
- iPhone: web en pantalla de inicio y, desde el 15/11, **app nativa instalada con Xcode** en el iPhone Air (R3Y), firma del equipo PTJG6N43MX válida hasta 15/11/2027. Reinstalar: `flutter build ios --release` y `xcrun devicectl device install app --device <id> build/ios/iphoneos/Runner.app`. Sin notificaciones push de Apple (los avisos son locales). Se instala por wifi (el iPhone está emparejado en red local); no caduca a los 7 días: firma de pago hasta 15/11/2027.
- Voz: Whisper local en el Mac para el habla libre; Azure para la nota de pronunciación.
- **Publicación automática**: cambios en `main` de GitHub → tests → migrar (panel → «Publicación»). La app Android va por parche aparte.

## Funciones hechas (recientes)
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
- [ ] Experimento Brainy: el panel recibe `experiments.brainy` en `metrics.json` pero aún no lo pinta. Límites conocidos del informe:
  los repasos y ejercicios salen de los puntos del día (`xp_days.by_source`), que tienen tope diario (100 repasos buenos); «palabras bien
  recordadas» cuenta todas las del alumno, no solo las de después de entrar; solo cuentan alumnos cuya app informó (la web no tiene Brainy).
- [ ] Sugerencias: **verlas y cambiar su estado** (new → reviewing → done / dismissed). Hoy solo se guardan; el panel recibe el conteo
  en `metrics.json` (bloque `suggestions`) pero aún no lo pinta ni hay pantalla para leerlas. Sin capturas de pantalla (decidido).
- [ ] Brainy · ajustar con datos reales: los puntos, metas y ritmos de `config/pet.php` están puestos a ojo (horas por corazón, cuánto
  da cada cosa, topes de desorden). Sin hacer del diseño del HANDOFF: **avisos locales** de Brainy (máx. 2 al día, nunca de noche; no
  añadí ninguno), frases con solo palabras ya aprendidas (hoy son 6 frases fijas de inglés muy fácil), árbol de evolución con dibujo
  (hoy es una lista con fechas). Sigue el **Paso 6b** («Enséñale una palabra»).
- [ ] Las rutas `/api/*` sin la cabecera `Accept: application/json` y sin sesión dan **500** («Route [login] not defined») en vez de
  401. Viene de antes (pasa en `/api/progress` también); la app siempre manda la cabecera, así que no se nota. Arreglo fácil: que la
  API responda siempre JSON.
- [ ] (opcional) Usar `hf.server()` en los demás ejercicios de manos libres (Oído, Sonido, shadowing, narración) para que un error suelto tampoco los pause.
- Mini-taller de palabra en la web (`speak.js`): solo está en la app.
- Palabras nuevas que se añadan: escribir su contenido con Claude Code y `words:content` (si no, las rellena el API de noche como antes).
- [ ] La pestaña Hoy de la app no muestra el protector (`/session/today` no lo trae); solo Progreso.
- [ ] (opcional) Seguir partiendo `public/app/app.js` (~1100 líneas): niveles, conversación.
- [ ] (opcional) Cloudflare mete su script de estadísticas (beacon) y la CSP lo bloquea: apagar «Web Analytics» automático en Cloudflare para W2W o dejarlo así (no rompe nada).

## Decisiones
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
