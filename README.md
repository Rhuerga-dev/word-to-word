# Word to Word

A web app for learning English from beginner to fluent. It follows the CEFR levels (A1 to C1): a placement test puts you at the right level, each level has its own vocabulary and goals, and an exam unlocks the next one. Every day you get new words plus spaced-repetition reviews, memory scenes, speaking practice with pronunciation scoring, AI conversation, and a daily push reminder.

> Documentación en español: [README.es.md](README.es.md)

## Features

- **CEFR learning path (A1 → C1):** placement test, words grouped by level, can-do goals per level, progress bar, and a level-up exam (80% to pass).
- **Accounts:** sign up, sign in, email verification and password reset by email.
- **Daily queue:** reviews first, then new words from your level (daily amount is configurable).
- **Freelance pack:** optional vocabulary for client calls, studied first.
- **Spaced repetition:** intervals of 1, 3, 7, 15, 30, 60 and 120 days; grade each review as again / hard / good / easy.
- **Memory scenes (AID):** write your own scene for each word, or get 3 suggestions from AI.
- **Pronunciation practice:** per-word and per-sound scoring (Azure Speech) or a browser fallback; mispronounced words are drilled one by one with mouth-position tips for Spanish speakers.
- **AI conversation:** chat in English and get feedback on your mistakes.
- **Daily reminder:** web push notification at the time you choose, only if you haven't studied yet.
- **Stats:** words learned and mastered, streak, 7-day forecast, weak sounds, and level history.
- **Installable on iPhone** as a PWA.

## Tech stack

- **Backend:** Laravel 13, PHP 8.4, MySQL, REST API with Laravel Sanctum, rate limiting, scheduled commands
- **Frontend:** single-page app in `public/app/` with a service worker
- **Push:** `laravel-notification-channels/webpush` (VAPID)
- **AI:** Claude API (scenes, word enrichment, conversation)
- **Speech:** Azure Pronunciation Assessment (optional)

## Getting started

```bash
composer install
composer require laravel-notification-channels/webpush
php artisan vendor:publish --provider="NotificationChannels\WebPush\WebPushServiceProvider" --tag="migrations"
cp .env.example .env              # set DB_*, MAIL_*, VAPID_SUBJECT
php artisan key:generate
php artisan webpush:vapid         # writes VAPID_PUBLIC_KEY / VAPID_PRIVATE_KEY
php artisan migrate
php artisan db:seed --class=WordSeeder            # 156 starter words
php artisan db:seed --class=FreelanceWordSeeder   # client-call vocabulary
php artisan test
php artisan serve
```

Open `http://localhost:8000/app/`, create an account and take the placement test.

### More words for higher levels

The starter list covers A1. Import the NGSL (about 2,800 words, free, CC BY-SA) to fill A2 to B2, then enrich it with translations and examples:

```bash
php artisan words:import storage/app/ngsl.csv
php artisan words:enrich
```

Level ranges are set in `config/vocab.php` (`levels`). C1 needs a longer word list.

### Server

- **Database:** MySQL. Create the database and user, then set `DB_*` in `.env`.
- **Email:** SMTP settings in `MAIL_*` (verification and password reset emails).
- **Scheduler** (daily reminders), in the server's crontab:
  ```
  * * * * * cd /path/to/word-to-word && php artisan schedule:run >> /dev/null 2>&1
  ```
- **Push on iPhone:** needs HTTPS, the app added to the Home Screen (iOS 16.4+), and a valid `VAPID_SUBJECT`.
- Set `VOCAB_ALLOW_TIME_TRAVEL=false` in production.

## Project structure

```
app/Services/SrsService.php              spaced repetition, daily queue and reviews
app/Services/LevelService.php            CEFR levels, placement test and level-up exam
app/Services/ClaudeService.php           AI scenes, word enrichment, conversation
app/Services/PronunciationService.php    Azure pronunciation assessment
app/Console/Commands/SendStudyReminders  daily push reminders (runs every 5 minutes)
app/Notifications/StudyReminder.php      reminder message
app/Http/Controllers/Api/                API endpoints
tests/Feature/                           account, level and reminder tests
public/app/index.html                    frontend
public/app/sw.js                         service worker (offline shell and push)
```
