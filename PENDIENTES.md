# W2W (Word to Word) · pendientes y estado

> Memoria del proyecto entre chats. **Léelo antes de empezar** y actualízalo al terminar.
> Lo mantiene al día la bitácora nocturna y el cierre de cada sesión.

_Última actualización: 2026-11-12_

## Estado actual
- **Servidor** Laravel en esta carpeta, publicado en `w2w.huergalabs.dev` por el túnel de Cloudflare (procesos en el panel).
- **App Android** (`mobile/`, Flutter): **1.0.14 (16)** en Play (prueba interna) con Shorebird; parches 1 (elegir profesión) y 2 (fuentes del tema) publicados.
- iPhone: versión web (no hay app nativa).
- Voz: Whisper local en el Mac para el habla libre; Azure para la nota de pronunciación.
- **Publicación automática**: cambios en `main` de GitHub → tests → migrar (panel → «Publicación»). La app Android va por parche aparte.

## Funciones hechas (recientes)
- Manos libres sin bucles: número de opción, nota hard/good/easy (también en español y con errores de oído) y sí/no; tras 3 fallos pide tocar la pantalla.
- Profesión y meta del alumno: escenarios y temas según su trabajo (12 profesiones; las de developer solo para «tech»).
- Recursos de la tienda: icono 512, gráfico 1024×500 y 4 capturas en `mobile/store/`.

## Pendiente (Reynaldo)
- [ ] Completar la ficha de Play con el icono, el gráfico, las capturas y las descripciones (corta y completa).
- [ ] Revisar `lang/en.json`: tiene 9 líneas cambiadas sin guardar que no son de Claude, y hay un `lang/en.json.lock` suelto. Mientras haya cambios sin guardar, la publicación automática de W2W se pausa.

## Pendiente (código)
- [ ] Recordatorios diarios como notificación en el iPhone (decidido, sin hacer).

## Decisiones
- Estilo Duolingo: sesión diaria guiada, camino por unidades, XP; enfoque en hablar con fluidez.
- Abierto a otros usuarios, no solo para Reynaldo.
- Nombre visible: W2W.
