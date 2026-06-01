alter table public.telegram_verifications
add column if not exists purpose text not null default 'register'
check (purpose in ('register', 'password_reset'));

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  target_role public.app_role not null default 'student',
  deep_link text,
  is_active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.notification_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists public.notification_reads (
  notification_id uuid not null references public.notifications(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (notification_id, user_id)
);

create index if not exists notifications_lookup_idx
on public.notifications (target_role, is_active, created_at desc);

alter table public.notifications enable row level security;
alter table public.notification_settings enable row level security;
alter table public.notification_reads enable row level security;

drop policy if exists "notifications_select_student_or_admin" on public.notifications;
create policy "notifications_select_student_or_admin"
on public.notifications for select
to authenticated
using (
  public.is_admin()
  or (
    is_active = true
    and target_role in ('student', 'teacher', 'admin')
  )
);

drop policy if exists "notifications_admin_all" on public.notifications;
create policy "notifications_admin_all"
on public.notifications for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "notification_settings_select_self" on public.notification_settings;
create policy "notification_settings_select_self"
on public.notification_settings for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "notification_settings_upsert_self" on public.notification_settings;
create policy "notification_settings_upsert_self"
on public.notification_settings for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "notification_reads_select_self" on public.notification_reads;
create policy "notification_reads_select_self"
on public.notification_reads for select
to authenticated
using (user_id = auth.uid() or public.is_admin());

drop policy if exists "notification_reads_write_self" on public.notification_reads;
create policy "notification_reads_write_self"
on public.notification_reads for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());
