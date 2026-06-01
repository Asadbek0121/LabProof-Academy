alter table public.profiles
add column if not exists gender text not null default '',
add column if not exists age int,
add column if not exists region text not null default '',
add column if not exists district text not null default '',
add column if not exists mahalla text not null default '',
add column if not exists street text not null default '';

alter table public.profiles
drop constraint if exists profiles_age_check;

alter table public.profiles
add constraint profiles_age_check
check (age is null or (age >= 10 and age <= 120));

drop policy if exists "avatars_public_read" on storage.objects;
create policy "avatars_public_read"
on storage.objects for select
using (bucket_id = 'avatars');

drop policy if exists "avatars_insert_self" on storage.objects;
create policy "avatars_insert_self"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'avatars'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists "avatars_update_self" on storage.objects;
create policy "avatars_update_self"
on storage.objects for update to authenticated
using (
  bucket_id = 'avatars'
  and auth.uid()::text = (storage.foldername(name))[1]
)
with check (
  bucket_id = 'avatars'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists "avatars_delete_self" on storage.objects;
create policy "avatars_delete_self"
on storage.objects for delete to authenticated
using (
  bucket_id = 'avatars'
  and auth.uid()::text = (storage.foldername(name))[1]
);
