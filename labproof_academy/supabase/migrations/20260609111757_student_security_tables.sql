create table if not exists public.user_security (
  user_id uuid primary key references auth.users(id) on delete cascade,
  pin_enabled boolean not null default false,
  biometric_enabled boolean not null default false,
  pin_updated_at timestamptz,
  biometric_updated_at timestamptz,
  failed_attempts integer not null default 0 check (failed_attempts >= 0),
  locked_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text,
  device_name text,
  platform text,
  browser text,
  ip_address inet,
  location text,
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, device_id)
);

alter table public.user_security enable row level security;
alter table public.devices enable row level security;

drop policy if exists "user_security_self_select" on public.user_security;
create policy "user_security_self_select"
on public.user_security for select
using (user_id = auth.uid() or public.is_admin());

drop policy if exists "user_security_self_insert" on public.user_security;
create policy "user_security_self_insert"
on public.user_security for insert
with check (user_id = auth.uid() or public.is_admin());

drop policy if exists "user_security_self_update" on public.user_security;
create policy "user_security_self_update"
on public.user_security for update
using (user_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or public.is_admin());

drop policy if exists "devices_self_select" on public.devices;
create policy "devices_self_select"
on public.devices for select
using (user_id = auth.uid() or public.is_admin());

drop policy if exists "devices_self_insert" on public.devices;
create policy "devices_self_insert"
on public.devices for insert
with check (user_id = auth.uid() or public.is_admin());

drop policy if exists "devices_self_update" on public.devices;
create policy "devices_self_update"
on public.devices for update
using (user_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or public.is_admin());

grant select, insert, update on public.user_security to authenticated;
grant select, insert, update on public.devices to authenticated;
