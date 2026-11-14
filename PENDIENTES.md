# W2W (Word to Word) · pendientes y estado

> Memoria del proyecto entre chats. **Léelo antes de empezar** y actualízalo al terminar.
> Lo mantiene al día la bitácora nocturna y el cierre de cada sesión.

_Última actualización: 2026-11-13_

## Estado actual
- **Servidor** Laravel en esta carpeta, publicado en `w2w.huergalabs.dev` por el túnel de Cloudflare (procesos en el panel).
- **App Android** (`mobile/`, Flutter): **1.0.14 (16)** en Play (prueba interna) con Shorebird; parches 1 (elegir profesión) y 2 (fuentes del tema) publicados.
- iPhone: versión web (no hay app nativa).
- Voz: Whisper local en el Mac para el habla libre; Azure para la nota de pronunciación.
- **Publicación automática**: cambios en `main` de GitHub → tests → migrar (panel → «Publicación»). La app Android va por parche aparte.

## Funciones hechas (recientes)
- Manos libres sin bucles: número de opción, nota hard/good/easy (también en español y con errores de oído) y sí/no; tras 3 fallos pide tocar la pantalla.
- Profesión y meta del alumno: escenarios y temas según su trabajo (12 profesiones; las de developer solo para «tech»).
- (13/11) Las traducciones que hace la IA sola (`i18n:translate`) ya no tocan `lang/en.json`: van a `storage/app/i18n/` (fuera de git), así no pausan la publicación. Para fijarlas en git: `php artisan i18n:promote` y commit.
- (13/11) Web: «Ajustes» es ahora la 5.ª pestaña de la barra de abajo (antes estaba al final de Progreso y no se encontraba).
- (13/11) Recordatorios en el iPhone: ya estaban hechos (web push desde la app instalada en pantalla de inicio); el 13/11 a las 19:00 salió uno.
- (13/11) Voz: Azure espera como mucho 8 s y, si falla, queda «caído» 1 minuto; la web corta a los 10 s y usa la voz del teléfono.
- (13/11) «Reiniciar progreso» pide la contraseña (salvo en la demo).
- (13/11) Web: app.js partido en handsfree.js, lab.js y boot.js (boot.js va el último). Guion de prueba con Chrome automático: ver git log.
- (13/11) App: tests del inicio de sesión (entrar, contraseña mal, token guardado, 401). Laravel 13.42; composer audit limpio.
- (13/11) SQLite con modo WAL y espera de 5 s: arregla los errores «database is locked».
- Recursos de la tienda: icono 512, gráfico 1024×500 y 4 capturas en `mobile/store/`.

## Pendiente (Reynaldo)
- [ ] Confirmar que al iPhone le llegó el recordatorio de las 19:00 del 13/11 (el servidor lo envió sin error).
- [ ] Decidir si borrar `_to_delete/` (2 copias viejas de index.html del 31/10, fuera de git).
- [ ] (opcional) En la app Android, «Ajustes» sigue dentro de Progreso: decidir si también va como pestaña (sería parche de Shorebird).
- [ ] Completar la ficha de Play con el icono, el gráfico, las capturas y las descripciones (corta y completa).

## Pendiente (código)
- [ ] (opcional) Seguir partiendo `public/app/app.js` (~1100 líneas): niveles, conversación.
- [ ] (opcional) Cloudflare mete su script de estadísticas (beacon) y la CSP lo bloquea: apagar «Web Analytics» automático en Cloudflare para W2W o dejarlo así (no rompe nada).

## Decisiones
- Estilo Duolingo: sesión diaria guiada, camino por unidades, XP; enfoque en hablar con fluidez.
- Abierto a otros usuarios, no solo para Reynaldo.
- Nombre visible: W2W.
