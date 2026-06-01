create extension if not exists pgcrypto;

alter table public.modules
add column if not exists access_level text not null default 'student',
add column if not exists price_monthly numeric(12,2) not null default 0,
add column if not exists price_yearly numeric(12,2) not null default 0,
add column if not exists media_public_id text,
add column if not exists metadata jsonb not null default '{}'::jsonb;

create table if not exists public.students (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users(id) on delete cascade,
  full_name text not null,
  email text,
  phone text,
  status text not null default 'active' check (status in ('active', 'average', 'risk', 'blocked')),
  progress numeric(5,2) not null default 0 check (progress between 0 and 100),
  average_score numeric(5,2) not null default 0 check (average_score between 0 and 100),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.certificates
drop constraint if exists certificates_user_id_module_id_key;

alter table public.certificates
add column if not exists certificate_code text,
add column if not exists title text not null default 'Sertifikat',
add column if not exists status text not null default 'issued' check (status in ('draft', 'pending', 'issued', 'revoked')),
add column if not exists qr_code_url text,
add column if not exists verify_url text,
add column if not exists file_public_id text,
add column if not exists metadata jsonb not null default '{}'::jsonb,
add column if not exists created_by uuid references auth.users(id) on delete set null,
add column if not exists updated_at timestamptz not null default now();

create unique index if not exists certificates_certificate_code_key
on public.certificates (certificate_code)
where certificate_code is not null;

create table if not exists public.media_library (
  id uuid primary key default gen_random_uuid(),
  public_id text not null unique,
  secure_url text not null,
  resource_type text not null check (resource_type in ('image', 'video', 'raw', 'auto')),
  format text,
  kind text not null default 'file' check (kind in ('image', 'video', 'round_video', 'voice', 'pdf', 'document', 'text', 'file')),
  bytes bigint not null default 0,
  duration numeric,
  width int,
  height int,
  original_filename text,
  uploaded_by uuid references auth.users(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists media_library_kind_created_idx
on public.media_library (kind, created_at desc);

create index if not exists media_library_resource_idx
on public.media_library (resource_type, format);

create table if not exists public.roles (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  name text not null,
  description text not null default '',
  color text not null default '#2563EB',
  is_system boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.permissions (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  module text not null,
  action text not null,
  description text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.role_permissions (
  role_id uuid not null references public.roles(id) on delete cascade,
  permission_id uuid not null references public.permissions(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (role_id, permission_id)
);

create table if not exists public.user_roles (
  user_id uuid not null references auth.users(id) on delete cascade,
  role_id uuid not null references public.roles(id) on delete cascade,
  assigned_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (user_id, role_id)
);

create table if not exists public.notification_conversations (
  id uuid primary key default gen_random_uuid(),
  source text not null check (source in ('telegram', 'student_app', 'system')),
  participant_user_id uuid references auth.users(id) on delete set null,
  telegram_chat_id text,
  title text not null default '',
  is_online boolean not null default false,
  typing_at timestamptz,
  last_message_at timestamptz not null default now(),
  unread_admin_count int not null default 0,
  unread_student_count int not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.notification_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.notification_conversations(id) on delete cascade,
  sender_user_id uuid references auth.users(id) on delete set null,
  sender_type text not null check (sender_type in ('admin', 'student', 'bot', 'telegram')),
  message_kind text not null default 'text' check (message_kind in ('text', 'image', 'voice', 'video', 'round_video', 'file', 'pdf', 'document')),
  body text,
  media_id uuid references public.media_library(id) on delete set null,
  attachment_url text,
  attachment_name text,
  attachment_size bigint,
  duration numeric,
  read_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists notification_messages_conversation_created_idx
on public.notification_messages (conversation_id, created_at);

create table if not exists public.admin_settings (
  id uuid primary key default gen_random_uuid(),
  section text not null,
  key text not null,
  value jsonb not null default '{}'::jsonb,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  unique (section, key)
);

create table if not exists public.backup_jobs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  backup_type text not null check (backup_type in ('full', 'database')),
  size_bytes bigint,
  status text not null default 'queued' check (status in ('queued', 'running', 'success', 'failed', 'restored')),
  note text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists public.integration_connections (
  id uuid primary key default gen_random_uuid(),
  provider text not null unique,
  status text not null default 'connected' check (status in ('connected', 'pending', 'error', 'disabled')),
  public_config jsonb not null default '{}'::jsonb,
  secret_ref text,
  last_sync_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  plan_key text not null,
  billing_interval text not null check (billing_interval in ('monthly', 'yearly', 'course')),
  status text not null default 'active' check (status in ('active', 'past_due', 'cancelled', 'expired')),
  amount numeric(12,2) not null default 0,
  currency text not null default 'UZS',
  current_period_start timestamptz,
  current_period_end timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  subscription_id uuid references public.subscriptions(id) on delete set null,
  provider text not null check (provider in ('payme', 'click', 'stripe', 'manual', 'uzum')),
  amount numeric(12,2) not null,
  currency text not null default 'UZS',
  status text not null default 'pending' check (status in ('pending', 'successful', 'failed', 'refunded')),
  provider_payment_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.login_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  ip_address inet,
  user_agent text,
  location text,
  success boolean not null default true,
  failure_reason text,
  created_at timestamptz not null default now()
);

create table if not exists public.active_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  device_name text,
  browser text,
  ip_address inet,
  location text,
  last_seen_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '30 minutes',
  revoked_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.has_permission(permission_key text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin()
    or exists (
      select 1
      from public.user_roles ur
      join public.role_permissions rp on rp.role_id = ur.role_id
      join public.permissions p on p.id = rp.permission_id
      where ur.user_id = auth.uid()
        and p.key = permission_key
    );
$$;

alter table public.students enable row level security;
alter table public.media_library enable row level security;
alter table public.roles enable row level security;
alter table public.permissions enable row level security;
alter table public.role_permissions enable row level security;
alter table public.user_roles enable row level security;
alter table public.notification_conversations enable row level security;
alter table public.notification_messages enable row level security;
alter table public.admin_settings enable row level security;
alter table public.backup_jobs enable row level security;
alter table public.integration_connections enable row level security;
alter table public.subscriptions enable row level security;
alter table public.transactions enable row level security;
alter table public.login_history enable row level security;
alter table public.active_sessions enable row level security;

drop policy if exists "students_select_self_or_admin" on public.students;
create policy "students_select_self_or_admin"
on public.students for select
using (user_id = auth.uid() or public.is_admin());

drop policy if exists "students_admin_all" on public.students;
create policy "students_admin_all"
on public.students for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "certificates_admin_all" on public.certificates;
create policy "certificates_admin_all"
on public.certificates for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "media_library_admin_all" on public.media_library;
create policy "media_library_admin_all"
on public.media_library for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "media_library_authenticated_select" on public.media_library;
create policy "media_library_authenticated_select"
on public.media_library for select to authenticated
using (true);

drop policy if exists "roles_admin_all" on public.roles;
create policy "roles_admin_all"
on public.roles for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "permissions_admin_all" on public.permissions;
create policy "permissions_admin_all"
on public.permissions for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "role_permissions_admin_all" on public.role_permissions;
create policy "role_permissions_admin_all"
on public.role_permissions for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "user_roles_admin_all" on public.user_roles;
create policy "user_roles_admin_all"
on public.user_roles for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "notification_conversations_admin_all" on public.notification_conversations;
create policy "notification_conversations_admin_all"
on public.notification_conversations for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "notification_conversations_participant_select" on public.notification_conversations;
create policy "notification_conversations_participant_select"
on public.notification_conversations for select
using (participant_user_id = auth.uid() or public.is_admin());

drop policy if exists "notification_messages_admin_all" on public.notification_messages;
create policy "notification_messages_admin_all"
on public.notification_messages for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "notification_messages_participant_select" on public.notification_messages;
create policy "notification_messages_participant_select"
on public.notification_messages for select
using (
  public.is_admin()
  or exists (
    select 1
    from public.notification_conversations c
    where c.id = notification_messages.conversation_id
      and c.participant_user_id = auth.uid()
  )
);

drop policy if exists "admin_settings_admin_all" on public.admin_settings;
create policy "admin_settings_admin_all"
on public.admin_settings for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "backup_jobs_admin_all" on public.backup_jobs;
create policy "backup_jobs_admin_all"
on public.backup_jobs for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "integration_connections_admin_all" on public.integration_connections;
create policy "integration_connections_admin_all"
on public.integration_connections for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "subscriptions_self_or_admin_select" on public.subscriptions;
create policy "subscriptions_self_or_admin_select"
on public.subscriptions for select
using (user_id = auth.uid() or public.is_admin());

drop policy if exists "subscriptions_admin_all" on public.subscriptions;
create policy "subscriptions_admin_all"
on public.subscriptions for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "transactions_self_or_admin_select" on public.transactions;
create policy "transactions_self_or_admin_select"
on public.transactions for select
using (user_id = auth.uid() or public.is_admin());

drop policy if exists "transactions_admin_all" on public.transactions;
create policy "transactions_admin_all"
on public.transactions for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "login_history_self_or_admin_select" on public.login_history;
create policy "login_history_self_or_admin_select"
on public.login_history for select
using (user_id = auth.uid() or public.is_admin());

drop policy if exists "active_sessions_self_or_admin_select" on public.active_sessions;
create policy "active_sessions_self_or_admin_select"
on public.active_sessions for select
using (user_id = auth.uid() or public.is_admin());

drop policy if exists "active_sessions_self_update" on public.active_sessions;
create policy "active_sessions_self_update"
on public.active_sessions for update
using (user_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or public.is_admin());

insert into public.roles (key, name, description, color, is_system)
values
  ('admin', 'Admin', 'To''liq admin panel boshqaruvi', '#2563EB', true),
  ('teacher', 'Teacher', 'Kontent, test va xabarlar bilan ishlash', '#10B981', true),
  ('student', 'Student', 'Student app huquqlari', '#F59E0B', true)
on conflict (key) do update
set name = excluded.name,
    description = excluded.description,
    color = excluded.color,
    is_system = excluded.is_system,
    updated_at = now();

insert into public.permissions (key, module, action, description)
values
  ('students.read', 'students', 'read', 'Talabalarni ko''rish'),
  ('students.write', 'students', 'write', 'Talabalarni tahrirlash'),
  ('analytics.read', 'analytics', 'read', 'Tahlillarni ko''rish'),
  ('notifications.send', 'notifications', 'send', 'Xabar yuborish'),
  ('certificates.manage', 'certificates', 'manage', 'Sertifikat yaratish'),
  ('media.manage', 'media_library', 'manage', 'Media kutubxonani boshqarish'),
  ('settings.manage', 'settings', 'manage', 'Sozlamalarni boshqarish'),
  ('roles.manage', 'roles', 'manage', 'Rollarni boshqarish')
on conflict (key) do update
set module = excluded.module,
    action = excluded.action,
    description = excluded.description;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.key = 'admin'
on conflict do nothing;

insert into public.integration_connections (provider, status, public_config, secret_ref, last_sync_at)
values
  ('telegram', 'connected', '{"webhook": true}'::jsonb, 'TELEGRAM_BOT_TOKEN', now()),
  ('cloudinary', 'connected', '{"signed_upload": true, "auto_compression": true, "thumbnail_generation": true}'::jsonb, 'CLOUDINARY_API_SECRET', now()),
  ('smtp', 'connected', '{"provider": "resend"}'::jsonb, 'SMTP_PASSWORD', now()),
  ('payme', 'connected', '{}'::jsonb, 'PAYME_SECRET', now()),
  ('click', 'connected', '{}'::jsonb, 'CLICK_SECRET', now()),
  ('stripe', 'connected', '{}'::jsonb, 'STRIPE_SECRET_KEY', now()),
  ('resend', 'connected', '{}'::jsonb, 'RESEND_API_KEY', now())
on conflict (provider) do update
set status = excluded.status,
    public_config = excluded.public_config,
    secret_ref = excluded.secret_ref,
    last_sync_at = excluded.last_sync_at,
    updated_at = now();

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values
  ('admin-images', 'admin-images', true, 26214400, array['image/png','image/jpeg','image/webp','image/gif']),
  ('admin-videos', 'admin-videos', true, 2147483648, array['video/mp4','video/quicktime','video/webm']),
  ('admin-round-videos', 'admin-round-videos', true, 524288000, array['video/mp4','video/quicktime','video/webm']),
  ('admin-voice', 'admin-voice', true, 52428800, array['audio/ogg','audio/mpeg','audio/wav','audio/x-m4a','audio/mp4']),
  ('admin-pdf', 'admin-pdf', true, 104857600, array['application/pdf']),
  ('admin-files', 'admin-files', true, 104857600, array[
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'text/plain'
  ])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "admin_media_storage_select" on storage.objects;
create policy "admin_media_storage_select"
on storage.objects for select
using (
  bucket_id = any(array[
    'admin-images',
    'admin-videos',
    'admin-round-videos',
    'admin-voice',
    'admin-pdf',
    'admin-files'
  ])
);

drop policy if exists "admin_media_storage_insert" on storage.objects;
create policy "admin_media_storage_insert"
on storage.objects for insert to authenticated
with check (
  public.is_admin()
  and bucket_id = any(array[
    'admin-images',
    'admin-videos',
    'admin-round-videos',
    'admin-voice',
    'admin-pdf',
    'admin-files'
  ])
);

drop policy if exists "admin_media_storage_update" on storage.objects;
create policy "admin_media_storage_update"
on storage.objects for update to authenticated
using (
  public.is_admin()
  and bucket_id = any(array[
    'admin-images',
    'admin-videos',
    'admin-round-videos',
    'admin-voice',
    'admin-pdf',
    'admin-files'
  ])
)
with check (
  public.is_admin()
  and bucket_id = any(array[
    'admin-images',
    'admin-videos',
    'admin-round-videos',
    'admin-voice',
    'admin-pdf',
    'admin-files'
  ])
);

drop policy if exists "admin_media_storage_delete" on storage.objects;
create policy "admin_media_storage_delete"
on storage.objects for delete to authenticated
using (
  public.is_admin()
  and bucket_id = any(array[
    'admin-images',
    'admin-videos',
    'admin-round-videos',
    'admin-voice',
    'admin-pdf',
    'admin-files'
  ])
);
