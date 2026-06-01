create extension if not exists pgcrypto;

create type public.app_role as enum ('admin', 'teacher', 'student');
create type public.lesson_kind as enum ('pdf', 'text', 'video', 'external_pdf', 'link', 'rich_text');
create type public.question_difficulty as enum ('easy', 'medium', 'hard');

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  phone text unique,
  role public.app_role not null default 'student',
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.modules (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null default '',
  order_index int not null,
  cover_url text not null default '',
  level_label text not null default 'Boshlang‘ich',
  duration_label text not null default '',
  is_published boolean not null default false,
  is_locked boolean not null default true,
  is_sequential boolean not null default false,
  passing_score int not null default 70 check (passing_score between 1 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (order_index)
);

create table if not exists public.topics (
  id uuid primary key default gen_random_uuid(),
  module_id uuid not null references public.modules(id) on delete cascade,
  title text not null,
  description text not null default '',
  order_index int not null,
  cover_url text not null default '',
  duration_seconds int not null default 0,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (module_id, order_index)
);

create table if not exists public.lessons (
  id uuid primary key default gen_random_uuid(),
  topic_id uuid not null references public.topics(id) on delete cascade,
  kind public.lesson_kind not null,
  title text not null,
  body text,
  file_url text,
  duration_seconds int not null default 0,
  order_index int not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.quiz_questions (
  id uuid primary key default gen_random_uuid(),
  topic_id uuid references public.topics(id) on delete cascade,
  module_id uuid references public.modules(id) on delete cascade,
  question text not null,
  option_a text not null,
  option_b text not null,
  option_c text not null,
  option_d text,
  correct_option text not null check (correct_option in ('a', 'b', 'c', 'd')),
  difficulty public.question_difficulty not null default 'medium',
  points int not null default 1,
  created_at timestamptz not null default now(),
  check (topic_id is not null or module_id is not null)
);

create table if not exists public.topic_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  topic_id uuid not null references public.topics(id) on delete cascade,
  pdf_completed boolean not null default false,
  video_completed boolean not null default false,
  quiz_completed boolean not null default false,
  quiz_score int not null default 0,
  completed_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (user_id, topic_id)
);

create table if not exists public.module_results (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  module_id uuid not null references public.modules(id) on delete cascade,
  score int not null check (score between 0 and 100),
  passed boolean not null default false,
  attempt_count int not null default 1,
  created_at timestamptz not null default now(),
  unique (user_id, module_id)
);

create table if not exists public.certificates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  module_id uuid not null references public.modules(id) on delete cascade,
  certificate_url text,
  issued_at timestamptz not null default now(),
  unique (user_id, module_id)
);

create table if not exists public.telegram_verifications (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  phone text not null,
  code text not null,
  chat_id text,
  name_confirmed boolean not null default false,
  confirmed boolean not null default false,
  expires_at timestamptz not null default now() + interval '5 minutes',
  created_at timestamptz not null default now()
);

create table if not exists public.admin_inbox_messages (
  id uuid primary key default gen_random_uuid(),
  source text not null default 'student_app'
    check (source in ('student_app', 'telegram', 'system')),
  sender_user_id uuid references auth.users(id) on delete set null,
  sender_name text not null default '',
  sender_phone text not null default '',
  telegram_chat_id text,
  subject text not null,
  body text not null,
  is_read boolean not null default false,
  admin_reply text,
  replied_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.modules enable row level security;
alter table public.topics enable row level security;
alter table public.lessons enable row level security;
alter table public.quiz_questions enable row level security;
alter table public.topic_progress enable row level security;
alter table public.module_results enable row level security;
alter table public.certificates enable row level security;
alter table public.telegram_verifications enable row level security;
alter table public.admin_inbox_messages enable row level security;

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('admin', 'teacher')
  );
$$;

create policy "profiles_select_self_or_admin"
on public.profiles for select
using (id = auth.uid() or public.is_admin());

create policy "profiles_update_self"
on public.profiles for update
using (id = auth.uid())
with check (id = auth.uid());

create policy "published_modules_select"
on public.modules for select
using (is_published = true or public.is_admin());

create policy "published_topics_select"
on public.topics for select
using (is_published = true or public.is_admin());

create policy "lessons_select_for_published_topics"
on public.lessons for select
using (
  public.is_admin()
  or exists (
    select 1 from public.topics t
    where t.id = lessons.topic_id and t.is_published = true
  )
);

create policy "questions_select_for_admin"
on public.quiz_questions for select
using (public.is_admin());

create policy "questions_select_for_published_content"
on public.quiz_questions for select
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.topics t
    join public.modules m on m.id = t.module_id
    where t.id = quiz_questions.topic_id
      and t.is_published = true
      and m.is_published = true
  )
  or exists (
    select 1
    from public.modules m
    where m.id = quiz_questions.module_id
      and m.is_published = true
  )
);

create policy "progress_select_self_or_admin"
on public.topic_progress for select
using (user_id = auth.uid() or public.is_admin());

create policy "progress_write_self"
on public.topic_progress for all
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "results_select_self_or_admin"
on public.module_results for select
using (user_id = auth.uid() or public.is_admin());

create policy "results_write_self"
on public.module_results for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "certificates_select_self_or_admin"
on public.certificates for select
using (user_id = auth.uid() or public.is_admin());

create policy "admin_modules_all"
on public.modules for all
using (public.is_admin())
with check (public.is_admin());

create policy "admin_topics_all"
on public.topics for all
using (public.is_admin())
with check (public.is_admin());

create policy "admin_lessons_all"
on public.lessons for all
using (public.is_admin())
with check (public.is_admin());

create policy "admin_questions_all"
on public.quiz_questions for all
using (public.is_admin())
with check (public.is_admin());

create policy "admin_inbox_admin_all"
on public.admin_inbox_messages for all
using (public.is_admin())
with check (public.is_admin());

create policy "admin_inbox_student_insert"
on public.admin_inbox_messages for insert
to authenticated
with check (
  sender_user_id = auth.uid()
  and source = 'student_app'
);

insert into storage.buckets (id, name, public)
values
  ('pdf-lessons', 'pdf-lessons', false),
  ('videos', 'videos', false),
  ('certificates', 'certificates', false),
  ('avatars', 'avatars', true),
  ('module-covers', 'module-covers', true),
  ('media-library', 'media-library', false)
on conflict (id) do nothing;
