/* Escalera de español: desde el escalón 3 la interfaz va en inglés.
   Traduce los textos de la página (y las instrucciones habladas) sin tocar el resto del código:
   1) texto exacto; 2) con números, niveles (B1) y sonidos (/θ/) como variables; 3) frases largas dentro de otros textos.
   Lo que no está en el diccionario (palabras del alumno, ejemplos en inglés) se queda como está. */
(function () {
  const EN = {
    // ----- Barra, entrar y cuenta -----
    "Inglés de básico a fluido": "English from basic to fluent",
    "Nivel {l}": "Level {l}",
    "{n} días": "{n} days", "{n} día": "{n} day", "día": "day", "días": "days",
    "Salir": "Log out",
    "Aprende inglés todos los días, a tu ritmo.": "Learn English every day, at your own pace.",
    "Palabras nuevas según tu nivel, repasos cuando tocan y práctica de pronunciación con tu voz.": "New words for your level, reviews when they're due and pronunciation practice with your voice.",
    "Entrar": "Log in", "Nombre": "Name", "Correo": "Email", "Contraseña": "Password",
    "Repite la contraseña": "Repeat the password", "Crear cuenta": "Create account", "Crear mi cuenta": "Create my account",
    "¿Olvidaste tu contraseña?": "Forgot your password?", "¿Quieres verla primero?": "Want to see it first?",
    "Probar la demo, sin registrarte": "Try the demo, no sign-up",
    "Estás en la demo.": "You're in the demo.",
    "Este alumno de ejemplo (nivel {l}, con {n} semanas de historial) es solo para ti y se borra en {n} horas.": "This sample student (level {l}, with {n} weeks of history) is just for you and is deleted in {n} hours.",
    "Confirma tu correo": "Confirm your email", "Contraseña nueva": "New password",
    "Elige una contraseña nueva de al menos {n} caracteres.": "Choose a new password with at least {n} characters.",
    "Escribe tu correo y te enviamos un enlace para crear una contraseña nueva.": "Type your email and we'll send you a link to create a new password.",
    "Enviarme el enlace": "Send me the link", "Guardar contraseña": "Save password", "Recuperar contraseña": "Recover password",
    "Reenviar correo": "Resend email", "Volver a entrar": "Log in again", "Las contraseñas no coinciden.": "The passwords don't match.",
    "Tu sesión expiró. Entra otra vez.": "Your session expired. Log in again.",
    "¡Listo! Tu correo quedó confirmado.": "Done! Your email is confirmed.",
    "¡Listo! Tu correo quedó confirmado. Ya puedes entrar.": "Done! Your email is confirmed. You can log in now.",
    "para poder recuperar tu cuenta si olvidas la contraseña.": "so you can recover your account if you forget your password.",
    "Preparando tu demo…": "Preparing your demo…",
    "Cargando…": "Loading…",

    // ----- Navegación -----
    "Hoy": "Today", "Camino": "Path", "Practicar": "Practice", "Progreso": "Progress", "Secciones": "Sections",
    "Fichas": "Flashcards", "Hablar": "Speak", "🎙️ Hablar": "🎙️ Speak", "Chat escrito": "Written chat",
    "📊 Progreso": "📊 Progress", "Manos libres": "Hands-free", "Ajustes": "Settings",
    "Instala Word to Word": "Install Word to Word", "Instalar": "Install", "Ahora no": "Not now",
    "Agregar a pantalla de inicio": "Add to Home Screen", "Agrégala a tu pantalla de inicio para abrirla como una app.": "Add it to your home screen to open it like an app.",
    "en la barra de Safari": "in the Safari toolbar", "para poder instalarla.": "to install it.",
    "Estás dentro de otra app. Abre este enlace en": "You're inside another app. Open this link in",
    ". Si no aparece, desliza la lista hacia abajo.": ". If it doesn't show up, scroll the list down.",
    ". Ábrela siempre desde su ícono.": ". Always open it from its icon.",

    // ----- Hoy -----
    "Buenos días": "Good morning", "Buenas tardes": "Good afternoon", "Buenas noches": "Good evening",
    "Buenos días 👋": "Good morning 👋", "Buenas tardes 👋": "Good afternoon 👋", "Buenas noches 👋": "Good evening 👋",
    "{n} XP": "{n} XP", "{n} de {n} XP": "{n} of {n} XP",
    "Te faltan {n} XP para tu meta de hoy": "{n} XP left to reach today's goal",
    "¡Meta de hoy cumplida! 🎉": "Today's goal reached! 🎉",
    "Sesión de hoy": "Today's session", "Otra ronda": "Another round", "unos {n} min": "about {n} min",
    "{n} fichas": "{n} cards", "{n} repasos · {n} nuevas": "{n} reviews · {n} new",
    "Sonido {p}": "Sound {p}", "tu más débil": "your weakest", "Pronunciación": "Pronunciation", "una palabra difícil": "a hard word",
    "Shadowing": "Shadowing", "repite como un nativo": "repeat like a native",
    "Errores": "Mistakes", "ninguno pendiente": "none pending", "dilos bien": "say them right",
    "{n} errores": "{n} mistakes", "{n} error": "{n} mistake", "al día": "all caught up",
    "Empezar": "Start", "Camino {l} · Unidad {n}": "Path {l} · Unit {n}",
    "Hablaste hoy": "You spoke today", "{n} min": "{n} min", "Esta semana": "This week",
    "Hablar {n} min": "Speak {n} min", "Hablar {n} s": "Speak {n} s", "narración del día": "daily narration", "describe una foto": "describe a photo",
    "Puntos en total": "Total points", "Meta del día: {n} de {n} XP": "Daily goal: {n} of {n} XP",
    "Hoy no hay pendientes: la sesión será de pronunciación y hablar.": "Nothing due today: the session will be pronunciation and speaking.",
    "Cargando tu día…": "Loading your day…",

    // ----- Sesión guiada -----
    "Salir de la sesión": "Leave the session", "Repaso": "Review", "Palabra nueva": "New word", "Palabra nueva.": "New word.",
    "Ver la respuesta": "Show the answer", "La tengo": "Got it", "Continuar": "Continue", "¿Cómo te fue?": "How did it go?",
    "Olvidé": "Forgot", "Difícil": "Hard", "Bien": "Good", "Fácil": "Easy",
    "La repasarás pronto": "You'll review it soon", "No se guardó": "Not saved", "Mañana la repasas.": "You'll review it tomorrow.",
    "Dila en voz alta dos veces y úsala en una frase tuya.": "Say it out loud twice and use it in a sentence of your own.",
    "Dila en voz alta antes de ver la respuesta.": "Say it out loud before you see the answer.",
    "Explícalo en voz alta en inglés antes de ver la respuesta.": "Explain it out loud in English before you see the answer.",
    "Ver en español": "Show in Spanish", "Traducir": "Translate", "Escucha": "Listen",
    "¡Sesión completa!": "Session complete!", "¡Sesión completa! Estoy orgulloso de ti.": "Session complete! I'm proud of you.",
    "PUNTOS": "POINTS", "FICHAS BIEN": "CARDS RIGHT", "Precisión": "Accuracy", "TIEMPO": "TIME",
    "Cumpliste tu meta de hoy": "You reached today's goal",
    "¡Nueva palabra!": "New word!", "Sigue practicándolo": "Keep practicing it", "Vuelve mañana": "Come back tomorrow",
    "Toca y dila en voz alta": "Tap and say it out loud", "Dilo bien en voz alta": "Say it right out loud", "Dilo bien en voz alta.": "Say it right out loud.",
    "Dijiste:": "You said:", "Tus errores: dilo bien": "Your mistakes: say it right", "Entendí: “": "I understood: “",
    "Revisando lo que dijiste…": "Checking what you said…", "Empezar a hablar": "Start speaking", "Terminé de hablar": "I'm done speaking",
    "Terminé": "I'm done", "Ya terminé": "I'm done", "Saltar": "Skip", "Otra vez": "Again", "otra vez": "again",
    "Así sonaría más natural": "This would sound more natural", "Escucha la explicación": "Listen to the explanation",

    // ----- Fichas (pestaña) -----
    "Palabras y escenas": "Words and scenes", "Frases: escucho, repito y sigo": "Sentences: I listen, repeat and move on",
    "Te leo cada palabra y respondes hablando.": "I read each word and you answer out loud.",
    "Empecemos con calma: una palabra a la vez. 🌱": "Let's start calmly: one word at a time. 🌱",
    "Plan de hoy:": "Today's plan:", "repasar {n} palabras que ya viste y aprender {n} nuevas.": "review {n} words you've seen and learn {n} new ones.",
    "Meta de hoy": "Today's goal", "{n} de {n}": "{n} of {n}", "Te quedan:": "Left:", "{n} repasos": "{n} reviews", "{n} nuevas": "{n} new",
    "🌱 La estás aprendiendo": "🌱 You're learning it", "🌿 Ya la conoces un poco": "🌿 You know it a little", "🌳 Casi la dominas": "🌳 You've almost got it",
    "⭐ Repaso rápido": "⭐ Quick review", "✨ Palabra nueva": "✨ New word", "🇺🇸 Solo inglés": "🇺🇸 English only",
    "Común": "Common", "Muy común": "Very common", "Útil": "Useful",
    "¿Qué significa? Dilo en voz alta antes de ver la respuesta.": "What does it mean? Say it out loud before you see the answer.",
    "¿Qué significa?": "What does it mean?", "¿Qué palabra falta? Dila en inglés, sin pasar por el español.": "Which word is missing? Say it in English, without going through Spanish.",
    "Toca la ficha para ver la respuesta": "Tap the card to see the answer", "· o pulsa": "· or press", "Espacio": "Space",
    "Desliza la ficha a la derecha → cuando la tengas": "Swipe the card right → when you've got it", "Desliza la ficha": "Swipe the card",
    "Califica deslizando la ficha": "Rate it by swiping the card",
    "← Olvidé": "← Forgot", "↓ Difícil": "↓ Hard", "Bien →": "Good →", "↑ Fácil": "↑ Easy",
    "Olvidé ·": "Forgot ·", "Difícil ·": "Hard ·", "Bien ·": "Good ·", "Fácil ·": "Easy ·",
    "Toca para escuchar": "Tap to listen", "Toca la frase para oírla despacio.": "Tap the sentence to hear it slowly.",
    "¿Necesitas una pista? Toca aquí (o": "Need a hint? Tap here (or",
    "Tu escena AID": "Your AID scene", "Pensando una escena para recordarla…": "Thinking of a scene to remember it…",
    "Toca una para usarla. Mejor aún: edítala a tu manera.": "Tap one to use it. Better yet: edit it your way.",
    "Terminaste por hoy 🎉 ¡Gran trabajo!": "You're done for today 🎉 Great job!", "¡Terminaste por hoy! Excelente trabajo.": "You're done for today! Excellent work.",
    "¡Listo por hoy! Lo hiciste muy bien.": "Done for today! You did really well.",
    "✅ La sabía": "✅ I knew it", "❌ No la sabía": "❌ I didn't know it", "La sabía": "I knew it", "No la sabía": "I didn't know it", "No la sé": "I don't know it",
    "✓ Ya la tenías": "✓ You already had it", "✓ En tus fichas": "✓ In your cards",
    "¡Genial, a la lista! 📚": "Great, added to the list! 📚", "¡Guardada! ✨": "Saved! ✨", "¡La dominas! ⭐": "You've mastered it! ⭐",
    "¡Lo sabías! 👏": "You knew it! 👏", "¡Facilísima! 🚀": "Super easy! 🚀", "Bien, la repasamos pronto 👍": "Good, we'll review it soon 👍",
    "Normal, así se aprende 💪": "That's normal, that's how you learn 💪", "Tranquilo, la verás otra vez pronto 🙂": "No worries, you'll see it again soon 🙂",
    "¡Ya pasaste la mitad! 🙌": "You're past halfway! 🙌", "¡Última recta! Ya casi terminas. 🏁": "Final stretch! Almost done. 🏁",
    "¡Una más para tu colección!": "One more for your collection!", "¡Una a una se aprende!": "One at a time is how you learn!",
    "Vas muy bien 💪": "You're doing great 💪", "¡Buen comienzo! Sigue así.": "Great start! Keep it up.", "¡Te falta poco!": "Almost there!",
    "Leer respuestas en voz alta": "Read replies out loud",
    "Repaso espaciado:": "Spaced repetition:", "Mañana:": "Tomorrow:", "Próximo:": "Next:",
    "Cómo practicar": "How to practice", "Cómo funciona": "How it works",

    // ----- Manos libres (voz) -----
    "Ahora dila tú.": "Now you say it.", "Repítela.": "Repeat it.", "Tu turno, dila.": "Your turn, say it.", "Otra vez, dila tú.": "Again, you say it.",
    "No te oí. Habla un poco más cerca.": "I didn't hear you. Speak a little closer.", "No te oí.": "I didn't hear you.",
    "No te oí. Acércate al micrófono y prueba otra vez.": "I didn't hear you. Get closer to the mic and try again.",
    "No te oí. Acércate al micrófono.": "I didn't hear you. Get closer to the mic.", "No te oí. Habla cuando quieras…": "I didn't hear you. Speak whenever you're ready…",
    "No te oí. Habla un poco más cerca del micrófono.": "I didn't hear you. Speak a little closer to the mic.",
    "No te oí, no pasa nada. Repítela en tu mente.": "I didn't hear you, no problem. Repeat it in your head.",
    "No te oigo. Lo dejo en pausa.": "I can't hear you. I'll pause.", "No te oigo. Revisa el micrófono y vuelve a intentarlo.": "I can't hear you. Check the mic and try again.",
    "No oí nada. Habla más cerca.": "I didn't hear anything. Speak closer.",
    "Ya la conoces bien. Ahora en una frase.": "You know it well. Now in a sentence.", "Subimos de nivel: la frase completa.": "Level up: the whole sentence.",
    "Ahora úsala en una frase.": "Now use it in a sentence.", "Último paso. Úsalo en una frase.": "Last step. Use it in a sentence.",
    "Repite.": "Repeat.", "Repite la frase.": "Repeat the sentence.", "Otra vez. Escucha.": "Again. Listen.", "Una más, despacio.": "One more, slowly.",
    "Otra vez. Repite la frase completa.": "Again. Repeat the whole sentence.", "Otra vez, más despacio.": "Again, more slowly.",
    "¡Correcto!": "Correct!", "¡Exacto!": "Exactly!", "¡Muy bien!": "Very good!", "¡Eso es!": "That's it!", "¡Excelente!": "Excellent!",
    "¡Bien!": "Good!", "¡Bien! 💪": "Good! 💪", "¡Perfecto!": "Perfect!", "¡Impecable!": "Flawless!", "¡Como un nativo!": "Like a native!",
    "¡Así se dice!": "That's how you say it!", "¡Bien dicha!": "Well said!", "¡Esa es!": "That's the one!", "¡Mucho mejor!": "Much better!",
    "¡Ahora sí!": "Now you've got it!", "¡Casi!": "Almost!", "Casi. Otra vez.": "Almost. Again.", "Eso es.": "That's it.", "Bien.": "Good.",
    "¡Listo!": "Done!", "Listo": "Done", "¡Empecemos!": "Let's start!",
    "Muy bien, así se queda.": "Very good, that's how it sticks.", "¡Excelente! Así no se te olvida.": "Excellent! That way you won't forget it.",
    "¡Bien! Decirla en voz alta ayuda a recordarla.": "Good! Saying it out loud helps you remember it.",
    "Repítela tú. Decirla en voz alta la fija en tu memoria.": "Now you repeat it. Saying it out loud fixes it in your memory.",
    "¿La recordabas? Toca sí o no": "Did you remember it? Tap yes or no", "¿La recordabas? Toca sí o no.": "Did you remember it? Tap yes or no.",
    "Piensa qué significa.": "Think about what it means.", "En pausa. Actívalo de nuevo para seguir.": "Paused. Turn it on again to continue.",
    "En pausa. Pulsa «Seguir» para continuar.": "Paused. Press “Continue” to go on.", "En pausa: no te oí. Pulsa «Seguir» cuando quieras.": "Paused: I didn't hear you. Press “Continue” whenever you want.",
    "Algo falló. Vuelve a activar el modo manos libres.": "Something went wrong. Turn hands-free mode on again.",
    "Para parar, toca el interruptor.": "To stop, tap the switch.", "Modo frases. Te digo una frase, la repites, y si está bien seguimos.": "Sentence mode. I say a sentence, you repeat it, and if it's right we move on.",
    "Te escucho… (en español)": "Listening… (in Spanish)", "Te escucho… (en inglés)": "Listening… (in English)",
    "Seguimos. La practicaremos más tarde.": "Let's move on. We'll practice it later.", "La seguimos practicando otro día.": "We'll keep practicing it another day.",
    "Vamos por partes.": "Let's go step by step.",

    // ----- Hablar -----
    "Habla en voz alta": "Speak out loud", "📊 Ver progreso": "📊 See progress", "de {n} min hoy": "of {n} min today",
    "Conversación": "Conversation", "Elige una situación real y habla con la IA": "Pick a real situation and talk with the AI",
    "Narración del día": "Daily narration", "🗣️ Narración del día": "🗣️ Daily narration", "Un minuto hablando sin parar": "One minute speaking non-stop",
    "Describe la imagen": "Describe the picture", "🖼️ Describe la imagen": "🖼️ Describe the picture", "Dices lo que ves en una foto": "Say what you see in a photo",
    "Repite frases como un nativo": "Repeat sentences like a native", "Ajustes de voz": "Voice settings",
    "⚡ Respuesta rápida": "⚡ Quick answer", "Tienes {n} segundos para empezar a contestar: así no da tiempo a traducir.": "You have {n} seconds to start answering: no time to translate.",
    "Arranca en {n} s, sin traducir": "Start within {n} s, without translating",
    "⏱ ¡Arranca! Di lo primero que se te ocurra, aunque sea simple.": "⏱ Go! Say the first thing that comes to mind, even if it's simple.",
    "Cuánto espero cuando haces una pausa": "How long I wait when you pause", "Poco ({n} s)": "Short ({n} s)", "Normal ({n} s)": "Normal ({n} s)", "Mucho ({n} s)": "Long ({n} s)",
    "💬 Elige una situación": "💬 Pick a situation", "Preparando la conversación…": "Preparing the conversation…",
    "Otra conversación": "Another conversation", "Nueva conversación": "New conversation",
    "Habla usando tus palabras de hoy": "Speak using today's words", "Enviar": "Send",
    "Escribe o dicta tu respuesta en inglés…": "Type or dictate your answer in English…", "Dictar": "Dictate",
    "Pulsa Enviar con el campo vacío para que la IA empiece.": "Press Send with the box empty to let the AI start.",
    "¿No sabes una palabra? Descríbela con otras (": "Don't know a word? Describe it with others (",
    "🎙️ Tu turno: habla ahora": "🎙️ Your turn: speak now", "🎙️ Practicar hablando": "🎙️ Practice speaking", "🎙️ Empezar a describir": "🎙️ Start describing", "🎙️ Empezar": "🎙️ Start",
    "Escucha el tema…": "Listen to the topic…", "Habla un minuto. Empieza ya.": "Talk for one minute. Start now.",
    "Hablas un minuto sin parar, sin preparar nada. Luego ves una versión más natural de lo que dijiste y tus errores.": "You speak for one minute non-stop, without preparing. Then you see a more natural version of what you said and your mistakes.",
    "Te escucho: habla sin parar, aunque te equivoques.": "I'm listening: keep talking, even if you make mistakes.",
    "Te escucho: describe todo lo que ves.": "I'm listening: describe everything you see.", "Te escucho… habla con calma": "I'm listening… take your time",
    "Cuéntala en voz alta…": "Tell it out loud…", "Si te quedas en blanco, describe lo que ves o di": "If your mind goes blank, describe what you see or say",
    "Entendiendo lo que dijiste…": "Understanding what you said…", "Lo que dijiste": "What you said",
    "Para mejorar (": "To improve (", "Sin errores importantes. ¡Muy bien!": "No important mistakes. Very good!",
    "No se marcaron errores. ¡Muy bien! Prueba una situación más difícil.": "No mistakes flagged. Very good! Try a harder situation.",
    "Repasa estas palabras": "Review these words", "Repasar mis errores ahora": "Review my mistakes now", "Repaso de errores": "Mistake review",
    "Repásalos ahora diciéndolos bien en voz alta: es cuando más se fijan. Volverán en tus próximos repasos.": "Review them now by saying them right out loud: that's when they stick best. They'll come back in your next reviews.",
    "Buscando una foto…": "Looking for a photo…", "Otra foto": "Another photo", "Describe la foto. Empieza ya.": "Describe the photo. Start now.",
    "Mírala unos segundos. Di qué hay, qué hace la gente, dónde están, colores, cómo crees que se sienten…": "Look at it for a few seconds. Say what's there, what people are doing, where they are, colors, how you think they feel…",
    "La IA está mirando la foto y lo que dijiste…": "The AI is looking at the photo and what you said…",
    "Preparando el texto…": "Preparing the text…", "Escúchalo lento y luego normal, y copia el ritmo.": "Listen slowly, then at normal speed, and copy the rhythm.",
    "Técnica: lento → normal": "Technique: slow → normal", "✓ Paso de shadowing de la unidad completado.": "✓ Unit shadowing step completed.",
    "La conversación necesita ANTHROPIC_API_KEY en el servidor.": "Conversation needs ANTHROPIC_API_KEY on the server.",
    "La conversación necesita la IA activada en el servidor (ANTHROPIC_API_KEY).": "Conversation needs the AI enabled on the server (ANTHROPIC_API_KEY).",
    "La narración necesita la IA activada en el servidor (ANTHROPIC_API_KEY).": "Narration needs the AI enabled on the server (ANTHROPIC_API_KEY).",
    "Necesita la IA activada en el servidor (ANTHROPIC_API_KEY).": "Needs the AI enabled on the server (ANTHROPIC_API_KEY).",
    "No se entendió el audio. Habla un poco más fuerte y cerca del micrófono.": "The audio wasn't understood. Speak a little louder and closer to the mic.",
    "No se entendió el audio. Habla un poco más fuerte.": "The audio wasn't understood. Speak a little louder.",
    "No se entendió lo que dijiste. Prueba otra vez, un poco más alto.": "What you said wasn't understood. Try again, a bit louder.",
    "No se pudo usar el micrófono.": "Couldn't use the microphone.", "Permite el micrófono en el navegador.": "Allow the microphone in your browser.",
    "Para hablar hace falta el reconocimiento de voz (AZURE_SPEECH_KEY en el servidor, o Google Chrome).": "Speaking needs speech recognition (AZURE_SPEECH_KEY on the server, or Google Chrome).",
    "Necesita reconocimiento de voz: usa Chrome en la Mac o en Android, o activa Azure en el servidor.": "Needs speech recognition: use Chrome on Mac or Android, or enable Azure on the server.",
    "En el iPhone el reconocimiento del navegador no funciona. Hay que activar la evaluación en el servidor (AZURE_SPEECH_KEY).": "On iPhone browser speech recognition doesn't work. Server evaluation must be enabled (AZURE_SPEECH_KEY).",
    "La IA te habla y te escucha sola, sin botones. Para terminar di": "The AI talks and listens on its own, no buttons. To finish say",
    "o pulsa Terminar.": "or press Finish.", "Error de voz:": "Voice error:",
    "La voz local no está encendida (tts-local/Arrancar voz local.command).": "The local voice isn't running (tts-local/Arrancar voz local.command).",
    "Comparar voces:": "Compare voices:", "Azure no respondió.": "Azure didn't respond.",
    "min hablando hoy": "min spoken today", "min hoy": "min today", "conversación, narración, foto, shadowing": "conversation, narration, photo, shadowing",

    // ----- Pronunciación (taller) -----
    "🎯 Taller de pronunciación": "🎯 Pronunciation workshop", "Taller de pronunciación": "Pronunciation workshop", "Taller": "Workshop",
    "sonido por sonido": "sound by sound", "Cargando tus sonidos…": "Loading your sounds…", "Sonidos que te cuestan": "Sounds you struggle with",
    "{p} × {n}": "{p} × {n}", "Practica con el micrófono y aquí verás los sonidos que más te cuestan.": "Practice with the mic and you'll see the sounds that are hardest for you here.",
    "Practica fichas con el micrófono y aquí verás tus sonidos difíciles.": "Practice cards with the mic and you'll see your hard sounds here.",
    "Toca un sonido para practicarlo.": "Tap a sound to practice it.", "🧭 Guiado": "🧭 Guided", "✍️ Práctica": "✍️ Practice", "🏆 Dominio": "🏆 Mastery",
    "Guiado": "Guided", "Práctica": "Practice", "Dominio": "Mastery", "Niveles de cada sonido": "Levels for each sound",
    "Practicar · último: ": "Practice · last: ", "Difícil para hispanohablantes": "Hard for Spanish speakers",
    "Otros sonidos difíciles para hispanohablantes": "Other sounds that are hard for Spanish speakers",
    "Te explico el sonido, lo oyes despacio y te corrijo en cada intento.": "I explain the sound, you hear it slowly and I correct you on every try.",
    "Lo oyes una vez a velocidad normal. La explicación y el modelo lento, solo si los pides.": "You hear it once at normal speed. The explanation and the slow model only if you ask.",
    "Sin modelo: ves la palabra y la dices en frío, como en la vida real.": "No model: you see the word and say it cold, like in real life.",
    "Nivel Dominio: sin modelo. Lee y dilo tú.": "Mastery level: no model. Read it and say it.",
    "Nivel Práctica: lo oyes una vez. Si necesitas la explicación o el modelo lento, pídelo.": "Practice level: you hear it once. If you need the explanation or the slow model, ask for it.",
    "Si lo apruebas sin necesitar ninguna ayuda, saltas directo a Dominio.": "If you pass it without any help, you jump straight to Mastery.",
    "Lo apruebas sin ayudas y pasas a Dominio.": "Pass it without help and you move to Mastery.",
    "Si fallas o pides ayuda dos veces seguidas, vuelves a Práctica. El sonido solo queda dominado con un taller de Dominio sin ayudas.": "If you fail or ask for help twice in a row, you go back to Practice. A sound is only mastered with a Mastery workshop without help.",
    "💡 Cómo se hace": "💡 How it's done", "Cómo se hace": "How it's done", "Cómo se hace:": "How it's done:", "Cómo decirla": "How to say it",
    "🔊 Oír el modelo": "🔊 Hear the model", "🔊 Oír otra vez": "🔊 Hear it again", "Escucha otra vez": "Listen again", "Escucha una vez": "Listen once",
    "Escucha y repite": "Listen and repeat", "Escucha y toca la palabra": "Listen and tap the word", "Escucha la diferencia.": "Listen to the difference.",
    "Entrena el oído": "Train your ear", "Entrena el oído:": "Train your ear:", "¿Cuál oíste?": "Which one did you hear?", "Toca la palabra que oíste": "Tap the word you heard",
    "Di la palabra que oíste (o tócala)": "Say the word you heard (or tap it)", "Era esta. Escucha las dos.": "It was this one. Listen to both.",
    "Decir la palabra": "Say the word", "Decir la frase": "Say the sentence", "Decir la frase otra vez": "Say the sentence again", "Léela y dila": "Read it and say it",
    "Otra vez, sin modelo": "Again, no model", "Intentar otra vez": "Try again", "Intentar con otro": "Try another one",
    "Evaluando tu pronunciación…": "Evaluating your pronunciation…", "Sonido al": "Sound at", "El sonido salió al": "The sound came out at",
    "Lo marcado en rojo necesita práctica. Abajo te explico cómo decir cada palabra.": "What's marked in red needs practice. Below I explain how to say each word.",
    "Lo que más te costó hoy fue este sonido.": "The sound that was hardest for you today was this one.",
    "Practícalo unos minutos con estas palabras.": "Practice it for a few minutes with these words.",
    "No quedan más sonidos para hoy. ¡Buen trabajo!": "No more sounds for today. Good job!", "Seguimos con el siguiente sonido.": "Let's go on to the next sound.",
    "Lo dejamos aquí por ahora. Vuelve mañana: con el sueño de por medio sale mejor.": "Let's stop here for now. Come back tomorrow: it comes out better after a night's sleep.",
    "Con manos libres contestas todo hablando y al terminar un sonido pasa solo al siguiente. Comandos en inglés:": "With hands-free you answer everything by speaking, and after a sound it moves on by itself. Commands in English:",
    "Ahora entrena el oído. Te digo una palabra y tú tocas cuál oíste.": "Now train your ear. I say a word and you tap which one you heard.",
    "Ahora escucha la frase y repítela.": "Now listen to the sentence and repeat it.", "Ahora repite la frase completa para fijarla.": "Now repeat the whole sentence to lock it in.",
    "Ahora imita. Te la digo despacio y la repites. Evalúo solo este sonido.": "Now imitate. I say it slowly and you repeat it. I only evaluate this sound.",
    "Di cada palabra. Evalúo solo este sonido.": "Say each word. I only evaluate this sound.",
    "Di la palabra dos veces seguidas, como un eco.": "Say the word twice in a row, like an echo.",
    "Contraste. Di la primera palabra, la que tiene el sonido.": "Contrast. Say the first word, the one with the sound.",
    "Contraste. Escucha las dos y di la primera, la que tiene el sonido.": "Contrast. Listen to both and say the first one, the one with the sound.",
    "Escucha despacio, fíjate en la boca y repite exagerando el sonido.": "Listen slowly, watch the mouth and repeat, exaggerating the sound.",
    "Escúchala lenta y repítela separando las sílabas.": "Listen to it slowly and repeat it, separating the syllables.",
    "Escúchala lento e imita cada sonido.": "Listen to it slowly and imitate each sound.",
    "Escúchala lenta, dila separando sílabas, y luego {n} veces seguidas a velocidad normal. Exagera la boca al principio.": "Listen to it slowly, say it syllable by syllable, then {n} times in a row at normal speed. Exaggerate your mouth at first.",
    "Divide la frase: di primero las dos primeras palabras y luego el resto, sin parar.": "Split the sentence: say the first two words first and then the rest, without stopping.",
    "Más despacio. Exagera la boca y alarga el sonido.": "Slower. Exaggerate your mouth and stretch the sound.", "Una más. Exagera la boca.": "One more. Exaggerate your mouth.",
    "Te la digo una vez y la repites.": "I say it once and you repeat it.", "Vamos a practicar": "Let's practice", "Parar aquí": "Stop here",
    "Todavía no tengo ejercicios para {p}": "I don't have exercises for {p} yet", "Siguiente: {p}": "Next: {p}", "unos {n} minutos por sonido": "about {n} minutes per sound",
    "Sonidos que ya no están en Guiado:": "Sounds no longer in Guided:", "Sonido de “usual”": "The sound in “usual”",
    "O abierta (law)": "Open O (law)", "O deslizada (go)": "Gliding O (go)", "Y (yes)": "Y (yes)",
    "Para evaluar tu voz hace falta Azure Speech en el servidor o Google Chrome.": "Evaluating your voice needs Azure Speech on the server or Google Chrome.",
    "Para evaluar tu voz hace falta Azure Speech o Google Chrome.": "Evaluating your voice needs Azure Speech or Google Chrome.",
    "Saca la punta de la lengua entre los dientes y sopla aire sin vibrar. No es “s” ni “t”.": "Put the tip of your tongue between your teeth and blow air without vibrating. It's not “s” or “t”.",
    "Lengua entre los dientes igual que en “think”, pero haciendo vibrar la garganta. Suena parecido a la “d” suave de “cada”.": "Tongue between the teeth like in “think”, but vibrating your throat. It sounds like the soft Spanish “d” in “cada”.",
    "Apoya los dientes de arriba sobre el labio de abajo y haz vibrar. No juntes los labios: eso es “b”.": "Rest your top teeth on your bottom lip and vibrate. Don't close your lips: that's “b”.",
    "Junta los dos labios y suéltalos con fuerza. Diferénciala de la “v”, que usa dientes y labio.": "Press both lips together and release them hard. Keep it apart from “v”, which uses teeth and lip.",
    "Más relajada y corta que la “i” española, casi entre “i” y “e”. La boca casi no sonríe.": "More relaxed and shorter than the Spanish “i”, almost between “i” and “e”. The mouth barely smiles.",
    "Una “i” más larga y tensa, sonriendo un poco.": "A longer, tenser “i”, smiling a little.",
    "Abre mucho la boca, como para “a”, pero estira los labios como para “e”. Queda entre las dos.": "Open your mouth wide as for “a”, but stretch your lips as for “e”. It sits between the two.",
    "Una “u” relajada y corta, sin redondear mucho los labios.": "A relaxed, short “u”, without rounding your lips much.",
    "Una “u” larga con los labios bien redondos hacia adelante.": "A long “u” with your lips well rounded and pushed forward.",
    "Una “a” breve y relajada, con la boca medio abierta, sin tensión.": "A short, relaxed “a”, with your mouth half open, no tension.",
    "Una vocal muy débil y corta, casi un murmullo “uh”. Las sílabas sin acento casi siempre suenan así.": "A very weak, short vowel, almost a murmur “uh”. Unstressed syllables almost always sound like this.",
    "Es una “s” que vibra: pon la mano en el cuello y siente el zumbido. La “s” final de “is”, “was” y “has” suena así.": "It's a vibrating “s”: put your hand on your neck and feel the buzz. The final “s” in “is”, “was” and “has” sounds like this.",
    "Una “s” clara y sin vibración. Al inicio con consonante (speak, start) no pongas “e” delante.": "A clear “s” with no vibration. At the start before a consonant (speak, start) don't add an “e” in front.",
    "Redondea los labios hacia adelante y deja salir el aire como cuando pides silencio: “shhh”.": "Round your lips forward and let the air out like when you ask for silence: “shhh”.",
    "Como “sh” pero vibrando la garganta, parecido a la “ll” rioplatense.": "Like “sh” but vibrating your throat, similar to the Rioplatense “ll”.",
    "Como la “ch” del español, pero con los labios un poco hacia adelante.": "Like the Spanish “ch”, but with your lips pushed a little forward.",
    "Como “ch” pero haciendo vibrar la garganta. No es la “j” española ni la “y”.": "Like “ch” but vibrating your throat. It's not the Spanish “j” or “y”.",
    "Curva la lengua hacia atrás sin tocar el paladar y redondea un poco los labios. No vibra como la “r” española.": "Curl your tongue back without touching the roof of your mouth and round your lips a little. It doesn't roll like the Spanish “r”.",
    "Solo aire suave desde la garganta, como empañar un espejo. No la raspes como la “j” española.": "Just soft air from the throat, like fogging a mirror. Don't scrape it like the Spanish “j”.",
    "Termina con la parte de atrás de la lengua contra el paladar, sin soltar una “g” al final.": "End with the back of your tongue against the roof of your mouth, without releasing a “g” at the end.",
    "Al final de la palabra levanta la parte de atrás de la lengua: suena más oscura, casi “ul”.": "At the end of a word raise the back of your tongue: it sounds darker, almost “ul”.",
    "Empieza con los labios redondos como para decir “u” y ábrelos rápido. No pongas “g” delante.": "Start with round lips as if saying “u” and open them quickly. Don't put a “g” in front.",
    "Una “i” muy corta antes de la vocal. No la conviertas en “ll” ni en “j” inglesa.": "A very short “i” before the vowel. Don't turn it into “ll” or an English “j”.",
    "Abre la boca grande y baja la lengua, como cuando el médico te pide “aaa”.": "Open your mouth wide and lower your tongue, like when the doctor asks you to say “aaa”.",
    "Labios redondos y boca abierta, una “o” más larga y profunda que la española.": "Round lips and open mouth, an “o” longer and deeper than the Spanish one.",
    "Empieza en “o” y termina cerrando los labios hacia “u”: “ou”.": "Start on “o” and finish closing your lips toward “u”: “ou”.",
    "Empieza en “e” y termina en una “i” suave: “ei”.": "Start on “e” and end on a soft “i”: “ei”.",
    "Como la “e” española, pero un poco más abierta y corta. No la conviertas en “ei”.": "Like the Spanish “e”, but a bit more open and short. Don't turn it into “ei”.",
    "Haz vibrar la garganta al final: la vocal antes de “d” se alarga un poco.": "Vibrate your throat at the end: the vowel before “d” gets a bit longer.",

    // ----- Camino -----
    "Tu camino · {l} Intermedio": "Your path · {l} Intermediate", "Tu camino · {l} Básico": "Your path · {l} Basic", "Tu camino · {l} Elemental": "Your path · {l} Elementary",
    "Tu camino · {l} Intermedio alto": "Your path · {l} Upper intermediate", "Tu camino · {l} Avanzado": "Your path · {l} Advanced",
    "Unidad {n}": "Unit {n}", "Unidad": "Unit", "Unidad actual": "Current unit", "Palabras": "Words", "Aprender": "Learn",
    "un taller aprobado": "one workshop passed", "repite un diálogo del tema": "repeat a dialogue on the topic",
    "se abre al terminar los otros {n} pasos": "opens after the other {n} steps", "Se abre al pasar la unidad anterior": "Opens after you pass the previous unit",
    "Cargando tu camino…": "Loading your path…", "Todavía no hay unidades para tu nivel.": "There are no units for your level yet.",
    "No hay palabras nuevas listas para esta unidad todavía.": "There are no new words ready for this unit yet.",
    "Empezar la prueba": "Start the test", "🏆 ¡Unidad completada!": "🏆 Unit complete!", "Todavía no": "Not yet", "Última prueba: ": "Last test: ",
    "En la oficina": "At the office", "Compras y dinero": "Shopping and money", "Trabajo freelance": "Freelance work", "Salud y el médico": "Health and the doctor",
    "Viajes y problemas": "Travel and problems", "Presentar mi proyecto": "Presenting my project", "Reunión diaria del equipo": "Daily team meeting",
    "Prueba: Reunión diaria del equipo": "Test: Daily team meeting",

    "¿qué palabra falta?": "which word is missing?", "¿qué significa?": "what does it mean?", "Repaso · ¿qué significa?": "Review · what does it mean?",
    "Solo inglés · ¿qué palabra falta?": "English only · which word is missing?", "vuelve mañana": "back tomorrow", "vuelve en {n} días": "back in {n} days",
    "en {n} días": "in {n} days", "Completada": "Completed", "Abierta": "Open", "prueba {n}/{n}": "test {n}/{n}", "Hacer la prueba": "Take the test",
    "Mejor nota {n}/{n}": "Best score {n}/{n}", "Mejor nota —/{n}": "Best score —/{n}", "aprueba con {n}": "pass with {n}",
    "una conversación real con la IA, aprueba con {n}/{n}": "a real conversation with the AI, pass with {n}/{n}", "conversación": "conversation",

    // ----- Practicar -----
    "todo suma puntos": "everything earns points", "Elige tú qué hacer.": "You choose what to do.",
    "repasos y palabras nuevas": "reviews and new words", "conversación escribiendo": "typed conversation",

    // ----- Progreso -----
    "📊 Tu progreso": "📊 Your progress", "Tu progreso": "Your progress", "Cargando tu progreso…": "Loading your progress…",
    "Lo que te falta hoy": "What's left today", "Ir": "Go", "¡Todo hecho por hoy! 🎉 Vuelve mañana.": "All done for today! 🎉 Come back tomorrow.",
    "Tienes {n} fichas para repasar hoy.": "You have {n} cards to review today.", "Tienes {n} ficha para repasar hoy.": "You have {n} card to review today.",
    "Te faltan {n} min de hablar para tu meta de hoy.": "{n} more min of speaking to reach today's goal.",
    "Repasa {n} errores de tus conversaciones.": "Review {n} mistakes from your conversations.", "Repasa {n} error de tus conversaciones.": "Review {n} mistake from your conversations.",
    "Haz la narración del día: un minuto hablando sin parar.": "Do the daily narration: one minute speaking non-stop.",
    "El sonido {p} sigue en Guiado: haz su taller.": "The sound {p} is still in Guided: do its workshop.",
    "El sonido {p} sigue en Práctica: haz su taller.": "The sound {p} is still in Practice: do its workshop.",
    "Ya puedes hacer el examen para subir a {l}.": "You can now take the exam to move up to {l}.",
    "Tardas más de {n} s en arrancar: activa «Respuesta rápida» en Hablar.": "You take more than {n} s to start: turn on “Quick answer” in Speak.",
    "Hoy pediste español {n} vez. Mañana intenta explicarlo en inglés con otras palabras.": "You asked for Spanish {n} time today. Tomorrow try explaining it in English with other words.",
    "Hoy pediste español {n} veces. Mañana intenta explicarlo en inglés con otras palabras.": "You asked for Spanish {n} times today. Tomorrow try explaining it in English with other words.",
    "Liga de la semana": "This week's league", "Gana puntos esta semana para entrar en la liga · termina en {n} días.": "Earn points this week to join the league · ends in {n} days.",
    "Gana puntos esta semana para entrar en la liga · termina en {n} día.": "Earn points this week to join the league · ends in {n} day.",
    "Aparecer en la liga (solo nombre e inicial)": "Show me in the league (first name and initial only)",
    "Logros · {n} de {n}": "Achievements · {n} of {n}", "Nuevo logro": "New achievement", "Nuevos logros": "New achievements",
    "Primer paso": "First step", "Termina tu primera sesión de Hoy": "Finish your first Today session", "Una semana": "One week",
    "{n} días seguidos practicando": "{n} days in a row practicing", "Un mes": "One month", "Constante": "Consistent", "Cumple tu meta diaria {n} días": "Hit your daily goal {n} days",
    "{n} palabras": "{n} words", "Aprende {n} palabras": "Learn {n} words", "Rompiendo el hielo": "Breaking the ice", "Habla {n} minutos en total": "Speak {n} minutes in total",
    "Una hora hablando": "One hour speaking", "Conversador": "Conversationalist", "Termina {n} conversaciones": "Finish {n} conversations",
    "Sin frenos": "No brakes", "Habla {n} segundos seguidos sin pausas largas": "Speak {n} seconds in a row without long pauses",
    "Buen oído": "Good ear", "Domina tu primer sonido": "Master your first sound", "Aprendo de mis errores": "Learning from my mistakes", "Supera {n} errores": "Overcome {n} mistakes",
    "Primera unidad": "First unit", "Aprueba la prueba de una unidad": "Pass a unit test", "Nivel completo": "Level complete", "Completa todas las unidades de tu nivel": "Complete all the units of your level",
    "Tu nivel": "Your level", "Tu nivel:": "Your level:", "Tu nivel: {l} · Intermedio": "Your level: {l} · Intermediate", "Tu nivel: {l} · Básico": "Your level: {l} · Basic",
    "Tu nivel: {l} · Elemental": "Your level: {l} · Elementary", "Tu nivel: {l} · Intermedio alto": "Your level: {l} · Upper intermediate", "Tu nivel: {l} · Avanzado": "Your level: {l} · Advanced",
    "Intermedio": "Intermediate", "Básico": "Basic", "Elemental": "Elementary", "Intermedio alto": "Upper intermediate", "Avanzado": "Advanced",
    "superado": "passed", "actual": "current", "sin palabras": "no words",
    "{n} de {n} palabras · {n} dominadas": "{n} of {n} words · {n} mastered", "Al terminar este nivel podrás:": "When you finish this level you'll be able to:",
    "Explicar un proyecto y responder preguntas de un cliente": "Explain a project and answer a client's questions",
    "Entender llamadas claras sobre temas de trabajo": "Understand clear calls about work topics",
    "Escribir propuestas y correos sin traductor": "Write proposals and emails without a translator",
    "Aprende {n} palabras más para desbloquear el examen de {l}.": "Learn {n} more words to unlock the {l} exam.", "Ver el camino completo": "See the whole path",
    "aprendidas": "learned", "dominadas": "mastered", "días seguidos": "days in a row", "{n} palabras por aprender de {n}.": "{n} words left to learn out of {n}.",
    "Repasos próximos {n} días": "Reviews in the next {n} days", "mañana": "tomorrow", "Vocabulario": "Vocabulary",
    "Has visto {n} de {n} palabras de {l} ({n}%) y dominas {n}. Para el examen de {l} necesitas ver {n}.": "You've seen {n} of {n} {l} words ({n}%) and mastered {n}. For the {l} exam you need to see {n}.",
    "Has visto {n} de {n} palabras de {l} ({n}%) y dominas {n}. Ya puedes hacer el examen para {l}.": "You've seen {n} of {n} {l} words ({n}%) and mastered {n}. You can now take the {l} exam.",
    "Has visto {n} de {n} palabras de {l} ({n}%) y dominas {n}. Es el último nivel.": "You've seen {n} of {n} {l} words ({n}%) and mastered {n}. It's the last level.",
    "Palabras según cada cuánto las repasas: a la derecha, las que ya tienes firmes.": "Words by how often you review them: on the right, the ones you know solidly.",
    "nuevas": "new", "nueva": "new", "{n}d": "{n}d", "min en total": "min in total", "días con la meta": "days at goal", "pausas largas/min": "long pauses/min",
    "Minutos hablando por semana (la última es la actual):": "Minutes speaking per week (the last one is this week):", "esta": "this",
    "Palabras por minuto": "Words per minute", "Aún no hay datos suficientes.": "Not enough data yet.", "Segundos para arrancar": "Seconds to start",
    "Errores al hablar": "Speaking mistakes", "por superar": "to overcome", "para repasar hoy": "to review today", "superados": "overcome",
    "Habla en la pestaña Hablar y aquí verás tus errores y su tipo.": "Speak in the Speak tab and you'll see your mistakes and their type here.",
    "Progreso del nivel": "Level progress", "Familias de palabras": "Word families",
    "Elige un tema y tus palabras nuevas serán de esa familia. Aprender palabras agrupadas ayuda a recordarlas.": "Pick a topic and your new words will come from that family. Learning words in groups helps you remember them.",
    "Mezcla": "Mix", "las más comunes": "the most common", "Partes del cuerpo": "Body parts", "Comida": "Food", "Frutas": "Fruits", "Verduras": "Vegetables",
    "Bebidas": "Drinks", "Animales": "Animals", "La casa": "The house", "Ropa": "Clothes", "Familia": "Family", "Colores": "Colors", "El clima": "The weather",
    "Transporte": "Transportation", "Lugares de la ciudad": "Places in the city", "Emociones": "Emotions", "🔀 Palabras nuevas por frecuencia": "🔀 New words by frequency",
    "Tus palabras nuevas serán de:": "Your new words will come from:",

    // ----- Escalera de español -----
    "Tu español": "Your Spanish", "Escalón": "Step", "Automático": "Automatic",
    "Con español": "With Spanish", "Primero inglés": "English first", "Interfaz en inglés": "English interface", "Solo inglés": "English only",
    "Traducción a la vista y explicaciones en español.": "Translations visible and explanations in Spanish.",
    "Definición en inglés; el español solo si lo pides.": "Definitions in English; Spanish only if you ask.",
    "La app en inglés y español con límite diario.": "The app in English and Spanish with a daily limit.",
    "Sin español: todo se explica en inglés.": "No Spanish: everything is explained in English.",
    "Pensar en inglés es dejar de pasar por el español: cada escalón te quita un poco.": "Thinking in English means not going through Spanish: each step takes a little more away.",
    "veces hoy": "times today", "esta semana": "this week", "días sin español": "days without Spanish", "día sin español": "day without Spanish",
    "Automático (ahora: escalón {n}, según tu nivel)": "Automatic (now: step {n}, based on your level)", "Automático (ahora: escalón {n}, subiste por usar poco español)": "Automatic (now: step {n}, you moved up for using little Spanish)",
    "{n} · Con español": "{n} · With Spanish", "{n} · Primero inglés": "{n} · English first", "{n} · Interfaz en inglés": "{n} · English interface", "{n} · Solo inglés": "{n} · English only",
    "Tardas {n} s en empezar a hablar: señal de que traduces mentalmente. Prueba «Respuesta rápida» en Hablar.": "You take {n} s to start speaking: a sign you're translating in your head. Try “Quick answer” in Speak.",
    "Empiezas a hablar en {n} s de media. Menos de {n} s es buena señal.": "You start speaking in {n} s on average. Under {n} s is a good sign.",
    "Ya usaste el español de hoy. Mañana tienes más.": "You've used today's Spanish. You'll have more tomorrow.",
    "Estás en el escalón \"solo inglés\": aquí ya no hay español. Intenta explicarlo con otras palabras.": "You're on the “English only” step: there's no Spanish here. Try explaining it with other words.",

    // ----- Ajustes -----
    "Palabras nuevas por día": "New words per day", "Micrófono": "Microphone", "Minutos hablando por día": "Minutes speaking per day",
    "Usa el micrófono una vez (en Hablar o en una ficha) para ver los nombres.": "Use the mic once (in Speak or on a card) to see the names.",
    "Con AirPods: elige el": "With AirPods: choose the", "micrófono del iPhone": "iPhone microphone",
    "y la voz de la app se oirá con mejor calidad en los AirPods.": "and the app's voice will sound better in the AirPods.",
    "Vocabulario para clientes (freelance)": "Client vocabulary (freelance)", "Recordatorio diario": "Daily reminder", "Hora del recordatorio": "Reminder time",
    "Adelantar un día (para probar)": "Skip ahead one day (for testing)", "Opciones avanzadas": "Advanced options", "Reiniciar progreso": "Reset progress",
    "Se borra todo tu progreso. ¿Seguro?": "All your progress will be deleted. Are you sure?", "Sí, borrar": "Yes, delete", "Cancelar": "Cancel",
    "Te avisaremos a las": "We'll remind you at", "Las notificaciones todavía no están configuradas en el servidor.": "Notifications aren't set up on the server yet.",
    "No diste permiso para notificaciones. Actívalo en los ajustes del navegador.": "You didn't allow notifications. Turn them on in your browser settings.",
    "En el iPhone, primero instala la app: Compartir → Agregar a pantalla de inicio. Luego actívalo desde la app instalada.": "On iPhone, first install the app: Share → Add to Home Screen. Then turn it on from the installed app.",
    "IA: activa · Pronunciación: Azure": "AI: on · Pronunciation: Azure", "sin configurar": "not set up",

    // ----- Nivel y examen -----
    "Prueba de nivel": "Level test", "Hacer la prueba de nivel": "Take the level test", "Haz la prueba de nivel para empezar donde te corresponde.": "Take the level test to start where you belong.",
    "¿Desde qué nivel empezamos?": "Which level should we start from?", "O elige tu nivel": "Or choose your level", "Empezar en este nivel": "Start at this level",
    "Empezar a estudiar": "Start studying", "Empiezas en el nivel": "You start at level", "Preparando el examen…": "Preparing the exam…",
    "Examen de": "Exam for", "Examen para subir a": "Exam to move up to", "Sigues en": "You stay at",
    "Estás en el último nivel. Sigue repasando para dominarlo.": "You're at the last level. Keep reviewing to master it.",
    "Tus palabras nuevas empezarán desde este nivel. Cuando aprendas la mayoría, podrás presentar el examen para subir.": "Your new words will start from this level. When you learn most of them, you can take the exam to move up.",
    "! Es buen momento para el examen de nivel (en Progreso).": "! It's a good time for the level exam (in Progress).",
    "Repasar con toda la ayuda (no cambia tu nivel)": "Review with full help (doesn't change your level)",
  };

  // Fechas cortas en español (vie 13, 11 nov, miércoles, 11 nov).
  const WD = { lun: "Mon", mar: "Tue", "mié": "Wed", jue: "Thu", vie: "Fri", "sáb": "Sat", dom: "Sun" };
  const WDL = { lunes: "Monday", martes: "Tuesday", "miércoles": "Wednesday", jueves: "Thursday", viernes: "Friday", "sábado": "Saturday", domingo: "Sunday" };
  const MO = { ene: "Jan", feb: "Feb", mar: "Mar", abr: "Apr", may: "May", jun: "Jun", jul: "Jul", ago: "Aug", sept: "Sep", sep: "Sep", oct: "Oct", nov: "Nov", dic: "Dec" };

  const TOKEN = /\/[^/\s]{1,4}\/|\b[ABC][12]\b|\d+(?:[.,]\d+)?/g;
  const kindOf = m => m[0] === "/" ? "p" : /^[ABC][12]$/.test(m) ? "l" : "n";
  const NORM = {};
  for (const [k, v] of Object.entries(EN)) NORM[k] = v;
  // Frases largas para reemplazar dentro de textos mezclados (sin variables), las más largas primero.
  const FRAGS = Object.keys(EN).filter(k => k.length >= 12 && !/\{[npl]\}/.test(k)).sort((a, b) => b.length - a.length);

  function fill(tpl, vals) {
    const q = { n: [], p: [], l: [] };
    vals.forEach(v => q[kindOf(v)].push(v));
    return tpl.replace(/\{([npl])\}/g, (_, k) => q[k].length ? q[k].shift() : "");
  }
  function core(t) {
    if (EN[t] != null) return EN[t];
    const vals = [], key = t.replace(TOKEN, m => { vals.push(m); return "{" + kindOf(m) + "}"; });
    if (vals.length && NORM[key] != null) return fill(NORM[key], vals);
    let m;
    if ((m = t.match(/^(\d+) de (\d+)( · .*)?$/))) return m[1] + " of " + m[2] + (m[3] || "");
    if ((m = t.match(/^(lun|mar|mié|jue|vie|sáb|dom) (\d+)$/))) return WD[m[1]] + " " + m[2];
    if ((m = t.match(/^(?:(lunes|martes|miércoles|jueves|viernes|sábado|domingo), )?(\d+) (ene|feb|mar|abr|may|jun|jul|ago|sept?|oct|nov|dic)\.?$/))) return (m[1] ? WDL[m[1]] + ", " : "") + MO[m[3]] + " " + m[2];
    return null;
  }
  /** Traduce un texto de la interfaz; null si no lo conoce. */
  function tr(text, strict) {
    const t = String(text).replace(/\s+/g, " ").trim();
    if (!t) return null;
    let out = core(t);
    if (out != null) return out;
    // Emoji o símbolos delante/detrás: se traduce el centro.
    const m = t.match(/^([^\p{L}¿¡“"(]*)(.*?)([^\p{L}.!?…)”"]*)$/u);
    if (m && (m[1] || m[3])) { const c = core(m[2].trim()); if (c != null) return m[1] + c + m[3]; }
    // Partes separadas por " · ": se traduce cada una.
    if (t.includes(" · ")) {
      let any = false;
      const parts = t.split(" · ").map(p => { const x = tr(p, true); if (x != null) { any = true; return x; } return p; });
      if (any) return parts.join(" · ");
    }
    if (strict) return null;
    // Frases conocidas dentro del texto.
    let s = t, hit = false;
    for (const f of FRAGS) if (s.includes(f)) { s = s.split(f).join(EN[f]); hit = true; }
    return hit ? s : null;
  }

  // ----- Aplicar a la página -----
  const ORIG = new WeakMap(), MINE = new WeakMap(), ATTRS = ["placeholder", "aria-label", "title"];
  let on = false, obs = null, busy = false;
  const skip = el => !el || /^(SCRIPT|STYLE|TEXTAREA|INPUT)$/.test(el.tagName) || el.closest("[data-no-i18n],.msg,.sp-topic,.word,.fw,.ex,.fex,.def,.sess-word,.sess-ex,.sess-def");
  function doText(n) {
    if (skip(n.parentElement)) return;
    const orig = ORIG.has(n) ? ORIG.get(n) : n.nodeValue;
    if (!ORIG.has(n)) ORIG.set(n, orig);
    const out = tr(orig);
    if (out != null) { const lead = orig.match(/^\s*/)[0], trail = orig.match(/\s*$/)[0]; const v = lead + out + trail; if (n.nodeValue !== v) { n.nodeValue = v; MINE.set(n, v); } }
  }
  function doEl(el) {
    for (const a of ATTRS) {
      if (!el.hasAttribute(a)) continue;
      const key = "data-i18n-" + a;
      const orig = el.getAttribute(key) ?? el.getAttribute(a);
      if (!el.hasAttribute(key)) el.setAttribute(key, orig);
      const out = tr(orig); if (out != null && el.getAttribute(a) !== out) { el.setAttribute(a, out); const m = MINE.get(el) || {}; m[a] = out; MINE.set(el, m); }
    }
  }
  function walk(root) {
    if (root.nodeType === 3) return doText(root);
    if (root.nodeType !== 1 || skip(root)) return;
    doEl(root);
    const w = document.createTreeWalker(root, NodeFilter.SHOW_TEXT | NodeFilter.SHOW_ELEMENT);
    let n; while ((n = w.nextNode())) n.nodeType === 3 ? doText(n) : doEl(n);
  }
  function restore() {
    const w = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT | NodeFilter.SHOW_ELEMENT);
    let n; while ((n = w.nextNode())) {
      if (n.nodeType === 3) { if (ORIG.has(n)) { n.nodeValue = ORIG.get(n); ORIG.delete(n); } }
      else for (const a of ATTRS) { const k = "data-i18n-" + a; if (n.hasAttribute(k)) { n.setAttribute(a, n.getAttribute(k)); n.removeAttribute(k); } }
    }
  }
  function setOn(v) {
    if (v === on) return;
    on = v;
    document.documentElement.lang = v ? "en" : "es";
    if (v) {
      walk(document.body);
      obs = new MutationObserver(list => {
        if (busy) return; busy = true;
        try {
          for (const r of list) {
            // El código de la app cambió un texto: ese pasa a ser el original.
            if (r.type === "characterData") { if (r.target.nodeValue === MINE.get(r.target)) continue; ORIG.set(r.target, r.target.nodeValue); doText(r.target); }
            else if (r.type === "attributes") { if (r.target.getAttribute(r.attributeName) === (MINE.get(r.target) || {})[r.attributeName]) continue; const k = "data-i18n-" + r.attributeName; r.target.setAttribute(k, r.target.getAttribute(r.attributeName)); doEl(r.target); }
            else r.addedNodes.forEach(walk);
          }
        } finally { busy = false; }
      });
      obs.observe(document.body, { subtree: true, childList: true, characterData: true, attributes: true, attributeFilter: ATTRS });
    } else {
      if (obs) { obs.takeRecords(); obs.disconnect(); } obs = null;
      restore();
    }
  }

  window.I18N_EN = { tr, setOn, isOn: () => on, dict: EN };
})();

/** Interfaz en inglés desde el escalón 3 (lo decide el servidor en profile.spanish.ui). */
function uiEnglish() { return !!(typeof profile !== "undefined" && profile && profile.spanish && profile.spanish.ui === "en"); }
function applyUiLang() { window.I18N_EN.setOn(uiEnglish()); }
/** Instrucciones habladas: si la interfaz va en inglés y la frase está en el diccionario, se dice en inglés. */
function uiSpeech(text, lang) {
  if (!uiEnglish() || !String(lang || "").startsWith("es")) return [text, lang];
  const t = window.I18N_EN.tr(text, true);
  return t != null ? [t, String(lang).length > 2 ? "en-US" : "en"] : [text, lang];
}
