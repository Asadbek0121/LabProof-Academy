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
