-- LabProof Academy LMS extensions for inline lessons, media questions and premium gating.
-- Safe to run more than once.

alter table if exists public.modules
  add column if not exists free_topic_limit integer not null default 1,
  add column if not exists requires_subscription boolean not null default false,
  add column if not exists subscription_price_label text not null default '';

alter table if exists public.topics
  add column if not exists is_free boolean not null default false,
  add column if not exists requires_subscription boolean not null default false;

alter table if exists public.lessons
  add column if not exists source_type text not null default '';

alter table if exists public.quiz_questions
  add column if not exists question_type text not null default 'text',
  add column if not exists media_url text,
  add column if not exists media_kind text,
  add column if not exists explanation text;

create table if not exists public.subscription_plans (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  duration_months integer not null default 1,
  price_label text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_id uuid references public.subscription_plans(id) on delete set null,
  status text not null default 'active',
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists user_subscriptions_user_status_idx
  on public.user_subscriptions(user_id, status);
