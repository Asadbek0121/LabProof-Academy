-- Keep the Twitter-style community schema compatible with the student app.
-- The app reads/writes these columns directly through Supabase Data API.
alter table if exists public.community_posts
  add column if not exists attachments text[] default '{}',
  add column if not exists likes_count integer not null default 0,
  add column if not exists reposts_count integer not null default 0,
  add column if not exists replies_count integer not null default 0,
  add column if not exists views_count integer not null default 0,
  add column if not exists is_pinned boolean not null default false;

alter table if exists public.post_replies
  add column if not exists attachments text[] default '{}',
  add column if not exists likes_count integer not null default 0,
  add column if not exists replies_count integer not null default 0;

alter table if exists public.post_likes
  add column if not exists reaction_type text not null default 'like';

update public.post_likes
set reaction_type = 'like'
where reaction_type is null or btrim(reaction_type) = '';

-- Keep only one reaction per user/post, so like and dislike are mutually exclusive.
delete from public.post_likes newer
using public.post_likes older
where newer.post_id = older.post_id
  and newer.user_id = older.user_id
  and (
    newer.created_at < older.created_at
    or (newer.created_at = older.created_at and newer.ctid < older.ctid)
  );

alter table if exists public.post_likes
  drop constraint if exists post_likes_post_id_user_id_reaction_type_key;

create unique index if not exists post_likes_one_reaction_per_user
  on public.post_likes(post_id, user_id);

alter table if exists public.community_posts enable row level security;
alter table if exists public.post_likes enable row level security;
alter table if exists public.post_replies enable row level security;
alter table if exists public.post_reposts enable row level security;
alter table if exists public.post_bookmarks enable row level security;

drop policy if exists "post_likes_update_own" on public.post_likes;
create policy "post_likes_update_own"
on public.post_likes for update
to authenticated
using (auth.uid() = user_id or public.is_admin())
with check (auth.uid() = user_id or public.is_admin());

grant select, insert, update, delete on public.community_posts to authenticated;
grant select, insert, update, delete on public.post_likes to authenticated;
grant select, insert, delete on public.post_reposts to authenticated;
grant select, insert, update, delete on public.post_replies to authenticated;
grant select, insert, delete on public.post_bookmarks to authenticated;
