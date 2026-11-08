# Word to Word — versión con API (Laravel)

App para aprender inglés: cada día **X palabras nuevas**, **repasos espaciados** de las anteriores, **escenas AID** (acción irracional detallada) y **práctica de speaking** con calificación de pronunciación y conversación con IA.

Estos archivos van **encima de un proyecto Laravel nuevo** (Laravel 11 o 12, PHP 8.2+).

## Instalación

```bash
# 1. Proyecto Laravel nuevo + API con Sanctum
composer create-project laravel/laravel word-to-word-app
cd word-to-word-app
php artisan install:api          # crea routes/api.php e instala Sanctum

# 2. Copia el contenido de esta carpeta sobre el proyecto
#    (reemplaza routes/api.php y app/Models/User.php)
cp -R /ruta/a/word-to-word/{app,config,database,routes,public} .

# 3. Variables de entorno
cat /ruta/a/word-to-word/env.additions >> .env
#    y llena ANTHROPIC_API_KEY (y AZURE_SPEECH_KEY si la tienes)

# 4. Base de datos y palabras iniciales (156, ya traducidas)
php artisan migrate
php artisan db:seed --class=WordSeeder

# 5. Arrancar
php artisan serve
```

Abre **http://localhost:8000/app/** en Google Chrome, crea tu cuenta y empieza.

## Cargar la lista NGSL (~2.800 palabras)

1. Descarga la NGSL desde **newgeneralservicelist.com** (es gratis, licencia CC BY-SA). Sirve el CSV o un .txt con una palabra por línea, en orden de frecuencia.
2. Guárdala en `storage/app/ngsl.csv` y corre:

```bash
php artisan words:import storage/app/ngsl.csv
php artisan words:enrich --limit=100   # prueba con 100 primero
php artisan words:enrich               # luego todas las pendientes
```

`words:enrich` usa Claude para poner traducción, ejemplo y traducción del ejemplo. Una palabra solo aparece como "nueva" en la app cuando ya está enriquecida. Las 156 iniciales se respetan y la NGSL se agrega después de ellas.

## Qué usa cada servicio

| Función | Sin claves | Con ANTHROPIC_API_KEY | Con AZURE_SPEECH_KEY |
|---|---|---|---|
| Palabras diarias y repasos | ✔ | ✔ | ✔ |
| Escena AID escrita a mano | ✔ | ✔ | ✔ |
| Sugerir escenas AID con IA | — | ✔ | ✔ |
| Enriquecer NGSL | — | ✔ | ✔ |
| Conversación con IA | — | ✔ | ✔ |
| Pronunciación | Chrome compara lo que entendió | igual | Azure: puntaje por palabra y por sonido (IPA), fluidez, completitud |
| "Sonidos que te cuestan" | — | — | ✔ |

Las claves solo viven en el servidor; el navegador nunca las ve.

## Endpoints (`/api`, autenticación Bearer de Sanctum)

| Método | Ruta | Qué hace |
|---|---|---|
| POST | `/auth/register` · `/auth/login` | Devuelve `token` |
| POST | `/auth/logout` | Cierra la sesión |
| GET | `/config` | Qué servicios están activos |
| GET | `/today` | Cola del día: repasos primero, luego nuevas |
| GET | `/stats` | Aprendidas, dominadas, racha, pronóstico 7 días, sonidos débiles |
| PUT | `/settings` | `{daily_new}` |
| POST | `/words/{id}/learn` | Marca una palabra nueva como aprendida (repaso mañana) |
| POST | `/words/{id}/review` | `{grade: again\|hard\|good\|easy}` |
| PUT | `/words/{id}/aid` | Guarda tu escena AID |
| POST | `/words/{id}/aid/suggest` | 3 escenas con IA |
| POST | `/words/{id}/pronunciation` | `target=word\|sentence` + `audio` (WAV 16 kHz) o `score` |
| POST | `/conversation` | `{messages:[{role,content}]}` → `reply`, `feedback` (en español), `used` |
| POST | `/debug/next-day` | Adelanta un día (solo pruebas) |
| POST | `/reset` | Borra tu progreso |

## Cómo funciona el repaso

Intervalos por nivel: 1, 3, 7, 15, 30, 60, 120 días (`config/vocab.php`).

- **Olvidé:** vuelve a nivel 0 y aparece mañana.
- **Difícil:** se queda en su nivel, con la mitad del intervalo.
- **Bien:** sube 1 nivel.
- **Fácil:** sube 2 niveles.

Una palabra es "dominada" desde el nivel 4.

## Archivos

```
app/Services/SrsService.php            lógica de días, cola y repasos
app/Services/ClaudeService.php         AID, enriquecer, conversación
app/Services/PronunciationService.php  Azure Pronunciation Assessment
app/Http/Controllers/Api/*             endpoints
app/Console/Commands/*                 words:import, words:enrich
database/migrations/*                  words, user_words, study_days, phoneme_errors, campos en users
database/seeders/WordSeeder.php        156 palabras iniciales
public/app/index.html                  frontend (consume la API)
```

## Instalar en el iPhone (PWA)

1. En la Mac, dentro de la carpeta: `bash tunnel.sh` (arranca Laravel en el puerto 8002 y abre un túnel HTTPS de Cloudflare).
2. Copia la dirección `https://….trycloudflare.com` que aparece y ábrela en **Safari** del iPhone agregando `/app/` al final.
3. Toca **Compartir → Agregar a pantalla de inicio**.

La app queda con su ícono y se abre a pantalla completa. El micrófono funciona porque la conexión es HTTPS.

La dirección del túnel rápido cambia cada vez que lo abres, y el ícono guardado apunta a la dirección vieja. Para algo fijo, usa un túnel con nombre de Cloudflare con tu propio dominio, o sube la app a un servidor.
