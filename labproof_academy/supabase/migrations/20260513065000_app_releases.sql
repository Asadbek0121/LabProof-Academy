create table if not exists public.app_releases (
  id uuid primary key default gen_random_uuid(),
  platform text not null,
  channel text not null default 'student',
  version_name text not null,
  version_code integer not null,
  download_url text not null,
  release_notes text,
  is_active boolean not null default true,
  is_required boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists app_releases_lookup_idx
on public.app_releases (platform, channel, is_active, version_code desc);

alter table public.app_releases enable row level security;

drop policy if exists "app_releases_public_read" on public.app_releases;
create policy "app_releases_public_read"
on public.app_releases for select
using (true);

drop policy if exists "app_releases_admin_all" on public.app_releases;
create policy "app_releases_admin_all"
on public.app_releases for all
using (public.is_admin())
with check (public.is_admin());

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'app-releases',
  'app-releases',
  true,
  104857600,
  array['application/vnd.android.package-archive']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;
