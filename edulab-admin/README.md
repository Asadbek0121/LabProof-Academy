# EduLab Admin

Next.js 15 App Router admin panel for LabProof Academy.

## Included

- Dark fixed/collapsible EduLab sidebar, top search, notification menu, profile dropdown.
- Pages: Talabalar, Tahlillar, Xabarnomalar, Sertifikatlar, Media kutubxona, Sozlamalar, Rollar.
- Cloudinary signed media actions for image/video/round video/voice/pdf/document upload, transform metadata, delete.
- Supabase SSR auth, middleware protection, RBAC helpers, React Query hooks, Zustand UI store.
- Supabase migration and edge function skeletons live in `../labproof_academy/supabase`.

## Run

```bash
npm install
npm run dev
```

Open `http://127.0.0.1:3000`.

## Mac desktop app

The admin panel can be packaged as a local macOS app with an embedded Next.js
server. Supabase, Cloudinary, and student-app links keep working because the
runtime environment is copied into the app resources during packaging.

```bash
npm run desktop:pack
```

The generated app is available here:

```text
dist/mac-arm64/LabProof Admin.app
```

For a DMG installer, use:

```bash
npm run desktop:build
```

This needs enough free disk space for both the `.app` bundle and the DMG file.

Environment notes:

- `npm run desktop:prepare-env` copies `.env`, `.env.local`, or
  `.env.production` into `desktop/runtime.env`.
- `desktop/runtime.env` is ignored by Git and must never be committed.
- On another Mac, app-specific overrides can be placed at:
  `~/Library/Application Support/LabProof Admin/admin.env`.
- Local builds are unsigned. The first launch may require right-clicking the app
  and choosing Open. Public distribution should use Apple Developer ID signing
  and notarization.

## Environment

Copy `.env.example` to `.env.local` and fill real secrets. Keep Cloudinary API secret and Supabase service role key out of Git.

Required runtime keys:

```bash
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=
NEXT_PUBLIC_APP_URL=http://127.0.0.1:3000
```
