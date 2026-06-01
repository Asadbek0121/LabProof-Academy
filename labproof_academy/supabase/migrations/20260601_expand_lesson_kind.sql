-- Migration to expand lesson_kind enum with additional lesson types
-- This allows the Flutter app to use external PDFs, links, and rich text content

-- Add new values to existing enum (safe operation that preserves data)
ALTER TYPE public.lesson_kind ADD VALUE IF NOT EXISTS 'external_pdf';
ALTER TYPE public.lesson_kind ADD VALUE IF NOT EXISTS 'link';
ALTER TYPE public.lesson_kind ADD VALUE IF NOT EXISTS 'rich_text';