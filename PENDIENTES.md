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
- (13/11) SQLite con modo WAL y espera de 5 s: arregla los errores «database is locked».
- Recursos de la tienda: icono 512, gráfico 1024×500 y 4 capturas en `mobile/store/`.

## Pendiente (Reynaldo)
- [ ] Completar la ficha de Play con el icono, el gráfico, las capturas y las descripciones (corta y completa).

## Pendiente (código)
- [ ] Recordatorios diarios como notificación en el iPhone (decidido, sin hacer).
- [ ] Voz: si Azure no responde, esperar menos (5 s), marcarlo caído 1 min y usar la voz del teléfono.
- [ ] Partir `public/app/app.js` (~2000 líneas) por pantallas.
- [ ] «Reiniciar progreso» (`/api/reset`) sin pedir contraseña: pedirla o escribir BORRAR.
- [ ] Más tests en la app Flutter (login, sesión diaria).
- [ ] Revisar si sobran `_to_delete/` y `env.additions`.
- [ ] Subir laravel/framework a 12.71+ (aviso de seguridad bajo CVE-2026-128083 en Concurrency; W2W no lo usa).

## Decisiones
- Estilo Duolingo: sesión diaria guiada, camino por unidades, XP; enfoque en hablar con fluidez.
- Abierto a otros usuarios, no solo para Reynaldo.
- Nombre visible: W2W.
