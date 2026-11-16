# W2W (Word to Word) · pendientes y estado

> Memoria del proyecto entre chats. **Léelo antes de empezar** y actualízalo al terminar.
> Lo mantiene al día la bitácora nocturna y el cierre de cada sesión.

_Última actualización: 2026-11-15_

## Estado actual
- **Servidor** Laravel en esta carpeta, publicado en `w2w.huergalabs.dev` por el túnel de Cloudflare (procesos en el panel).
- **App Android** (`mobile/`, Flutter): **1.0.14 (16)** en Play (prueba interna) con Shorebird; parches 1–3, **4** (15/11: protector de racha, informe semanal, recordatorio automático) **5** (loader al pensar), **6** («I heard» y consejos en Oído), **7** (nota por voz más tolerante) **8** (avisa «repeat/slower» para la escalera) **9** (registro con código de invitación) y **10** (loader «Evaluando…» en errores para repasar), todos del 15/11.
- Tests: servidor 193 ✓, app 68 ✓ (+2 saltados), `flutter analyze` limpio (15/11).
- Repasos con **FSRS** desde el 15/11 (`VOCAB_SRS=classic` en .env vuelve al sistema de saltos fijos).
- iPhone: web en pantalla de inicio y, desde el 15/11, **app nativa instalada con Xcode** en el iPhone Air (R3Y), firma del equipo PTJG6N43MX válida hasta 15/11/2027. Reinstalar: `flutter build ios --release` y `xcrun devicectl device install app --device <id> build/ios/iphoneos/Runner.app`. Sin notificaciones push de Apple (los avisos son locales). Se instala por wifi (el iPhone está emparejado en red local); no caduca a los 7 días: firma de pago hasta 15/11/2027.
- Voz: Whisper local en el Mac para el habla libre; Azure para la nota de pronunciación.
- **Publicación automática**: cambios en `main` de GitHub → tests → migrar (panel → «Publicación»). La app Android va por parche aparte.

## Funciones hechas (recientes)
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
- [ ] La pestaña Hoy de la app no muestra el protector (`/session/today` no lo trae); solo Progreso.
- [ ] (opcional) Seguir partiendo `public/app/app.js` (~1100 líneas): niveles, conversación.
- [ ] (opcional) Cloudflare mete su script de estadísticas (beacon) y la CSP lo bloquea: apagar «Web Analytics» automático en Cloudflare para W2W o dejarlo así (no rompe nada).

## Decisiones
- (15/11) Registro por invitación: códigos de varios usos con límite, creados por Reynaldo desde el panel.
- (15/11) La escalera de español tiene en cuenta cómo entiende el alumno al oír, no solo la prueba de nivel.
- (15/11) Prioridad: que la gente vuelva y medirlo antes que añadir funciones. MySQL cuando haya ~100 usuarios activos.
- (15/11) FSRS activado para todos, con interruptor para volver al clásico. Gateway de IA sí (cuando exista la clave).
- (15/11) iPhone: app nativa instalada con Xcode (además de la web).
- Parches de Shorebird: solo iconos de Material que ya estaban en la versión de Play (la fuente de iconos va recortada). Un icono nuevo = versión nueva en Play, o elegir uno que ya se use.
- Estilo Duolingo: sesión diaria guiada, camino por unidades, XP; enfoque en hablar con fluidez.
- Abierto a otros usuarios, no solo para Reynaldo.
- Nombre visible: W2W.
