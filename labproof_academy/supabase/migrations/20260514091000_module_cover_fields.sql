alter table public.modules
add column if not exists cover_url text not null default '',
add column if not exists level_label text not null default 'Boshlang‘ich',
add column if not exists duration_label text not null default '',
add column if not exists is_sequential boolean not null default false;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'module-covers',
  'module-covers',
  true,
  2097152,
  array['image/png', 'image/jpeg', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "module_covers_public_read" on storage.objects;
create policy "module_covers_public_read"
on storage.objects for select
using (bucket_id = 'module-covers');

drop policy if exists "module_covers_admin_insert" on storage.objects;
create policy "module_covers_admin_insert"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'module-covers'
  and public.is_admin()
);

drop policy if exists "module_covers_admin_update" on storage.objects;
create policy "module_covers_admin_update"
on storage.objects for update to authenticated
using (
  bucket_id = 'module-covers'
  and public.is_admin()
)
with check (
  bucket_id = 'module-covers'
  and public.is_admin()
);

drop policy if exists "module_covers_admin_delete" on storage.objects;
create policy "module_covers_admin_delete"
on storage.objects for delete to authenticated
using (
  bucket_id = 'module-covers'
  and public.is_admin()
);
