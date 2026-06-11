-- Keep student profile edits and community posts writable from the mobile app.
-- This migration is intentionally idempotent because some projects already have
-- older profile/community policies applied under different names.

alter table public.profiles enable row level security;
grant select, insert, update on public.profiles to authenticated;

drop policy if exists "profiles_select_self_or_admin" on public.profiles;
create policy "profiles_select_self_or_admin"
on public.profiles for select
to authenticated
using (
  id = auth.uid()
  or public.is_admin()
);

drop policy if exists "profiles_insert_self" on public.profiles;
create policy "profiles_insert_self"
on public.profiles for insert
to authenticated
with check (id = auth.uid());

drop policy if exists "profiles_update_self" on public.profiles;
create policy "profiles_update_self"
on public.profiles for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "avatars_public_read" on storage.objects;
create policy "avatars_public_read"
on storage.objects for select
using (bucket_id = 'avatars');

drop policy if exists "avatars_insert_self" on storage.objects;
create policy "avatars_insert_self"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "avatars_update_self" on storage.objects;
create policy "avatars_update_self"
on storage.objects for update
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "avatars_delete_self" on storage.objects;
create policy "avatars_delete_self"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

alter table public.community_posts
add column if not exists title text not null default '';

alter table public.community_posts
add column if not exists attachments text[] not null default '{}'::text[];

alter table public.community_posts
add column if not exists category text not null default 'Barchasi';

alter table public.community_posts
add column if not exists likes_count integer not null default 0;

alter table public.community_posts
add column if not exists comments_count integer not null default 0;

alter table public.community_posts
add column if not exists reposts_count integer not null default 0;

alter table public.community_posts
add column if not exists replies_count integer not null default 0;

alter table public.community_posts
add column if not exists views_count integer not null default 0;

alter table public.community_posts
add column if not exists is_blocked boolean not null default false;

alter table public.community_posts enable row level security;
grant select, insert, update, delete on public.community_posts to authenticated;

drop policy if exists "community_posts_select_all" on public.community_posts;
drop policy if exists "community_posts_select_authenticated" on public.community_posts;
create policy "community_posts_select_authenticated"
on public.community_posts for select
to authenticated
using (
  coalesce(is_blocked, false) = false
  or public.is_admin()
);

drop policy if exists "community_posts_insert_own" on public.community_posts;
drop policy if exists "Allow users to create posts" on public.community_posts;
create policy "community_posts_insert_own"
on public.community_posts for insert
to authenticated
with check (author_id = auth.uid());

drop policy if exists "community_posts_update_own" on public.community_posts;
drop policy if exists "Allow author to delete/update posts" on public.community_posts;
create policy "community_posts_update_own"
on public.community_posts for update
to authenticated
using (
  author_id = auth.uid()
  or public.is_admin()
)
with check (
  author_id = auth.uid()
  or public.is_admin()
);

drop policy if exists "community_posts_delete_own" on public.community_posts;
create policy "community_posts_delete_own"
on public.community_posts for delete
to authenticated
using (
  author_id = auth.uid()
  or public.is_admin()
);
