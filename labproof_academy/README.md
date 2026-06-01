# LabProof Academy

Modern Flutter UI prototype for a laboratory-focused LMS with two experiences:

- Student mobile app: module locking, PDF/Text lessons, video lessons, topic quizzes, final module exam, pass/fail states, progress, analytics, certificates, profile, and settings.
- Desktop admin panel: dashboard analytics, module/topic/content/video/quiz/final exam management, students, results, notifications, certificates, media library, roles, and settings.

## Latest Auth And Language Flow

- Login uses phone number instead of email.
- `+998` is always visible and fixed in the phone input.
- Student registration is a staged Telegram verification flow:
  1. Enter full name, phone number, and password.
  2. Press `Ro‘yxatdan o‘tish`.
  3. Press `Kodni olish`.
  4. Backend creates a verification session and opens `https://t.me/LabProof_Support_bot`.
  5. After returning to the app, enter the Telegram code; a matching code completes registration.
- Student UI supports three languages: Uzbek Latin, Russian, and Uzbek Cyrillic.
- Admin UI is Uzbek-only.
- Student auth and screens no longer expose admin controls; admin login is opened
  from a separate admin URL such as `/?admin=1`.

## Learning Flow

```text
Splash
  -> Login/Register
  -> Student Dashboard
  -> Modules
  -> Module Detail
  -> PDF/Text Lesson
  -> Video Lesson
  -> Topic Quiz
  -> Next Topic
  -> Final Module Exam
  -> Passed: next module unlocked
  -> Failed: review lessons and retake exam
```

The final module exam uses a 70% passing rule.

## Structure

```text
lib/
  core/
    constants/
    theme/
    widgets/
  data/
    models/
    repositories/
  modules/
    auth/
    student/
    admin/
  routes/
  app.dart
  main.dart
```

## API-Ready Contracts

Endpoint constants live in `lib/core/constants/api_endpoints.dart` and mirror the planned REST API:

- `POST /login`
- `POST /register`
- `POST /auth/telegram/request-code`
- `POST /auth/telegram/verify-code`
- `GET /modules`
- `GET /module/:id`
- `GET /lesson/:id`
- `GET /video/:id`
- `GET /quiz/:id`
- `POST /quiz/:id/submit`
- `GET /progress`
- `POST /progress/update`

## Telegram Bot Backend

The bot token must stay on the backend, never inside Flutter or APK files.

## Supabase Setup

Flutter is now initialized with this Supabase project:

- URL: `https://kdwghotfxttlawfttphl.supabase.co`
- Public key: configured in `lib/core/constants/supabase_config.dart`

For production builds, pass keys through build defines:

```bash
flutter build apk \
  --dart-define=SUPABASE_URL=https://kdwghotfxttlawfttphl.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_publishable_key \
  --dart-define=LABPROOF_API_BASE_URL=https://kdwghotfxttlawfttphl.supabase.co/functions/v1
```

Database schema and policies are in:

```text
supabase/schema.sql
```

Telegram verification Edge Function scaffold is in:

```text
supabase/functions/auth/index.ts
```

The function is configured in `supabase/config.toml` with JWT verification
disabled so Telegram can call the webhook route.

Required Supabase secrets for the Edge Function:

```bash
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=...
supabase secrets set TELEGRAM_BOT_TOKEN=...
supabase secrets set TELEGRAM_BOT_USERNAME=LabProof_Support_bot
```

After deploy, point Telegram webhook to:

```bash
curl -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/setWebhook" \
  -d "url=https://kdwghotfxttlawfttphl.supabase.co/functions/v1/auth/telegram/webhook"
```

Do not put `SUPABASE_SERVICE_ROLE_KEY` or `TELEGRAM_BOT_TOKEN` in Flutter,
GitHub, or the APK.

```bash
cd server
cp .env.example .env
```

Add your Telegram token to `server/.env`, then run:

```bash
npm start
```

The Flutter app now uses Supabase Edge Functions by default for Telegram
verification. For local Node testing, override the auth API URL:

```bash
flutter run --dart-define=LABPROOF_API_BASE_URL=http://127.0.0.1:8787
```

## Run

```bash
flutter pub get
flutter run
```

For web:

```bash
flutter run -d web-server --web-hostname=127.0.0.1 --web-port=5174
```

## Verify

```bash
flutter analyze
flutter test
flutter build web
```
