# LabProof Telegram Verification Server

This server keeps the Telegram bot token outside the Flutter app.

## Setup

```bash
cd server
cp .env.example .env
```

Put the Telegram bot token into `server/.env`. Do not commit `.env`.
The default bot username is `LabProof_Support_bot`; change
`TELEGRAM_BOT_USERNAME` in `.env` only if the bot username changes.

```bash
npm start
```

The Flutter app uses `http://127.0.0.1:8787` by default. For another backend URL:

```bash
flutter run --dart-define=LABPROOF_API_BASE_URL=https://your-api.example.com
```

## Flow

1. Flutter calls `POST /auth/telegram/request-code`.
2. Server creates a verification session and returns a Telegram deep link.
3. Student opens the bot link and presses `Tasdiqlayman`.
4. Bot sends the verification code.
5. Flutter calls `POST /auth/telegram/verify-code`.
