alter table public.community_posts
add column if not exists attachments text[] default '{}'::text[];

alter table public.community_posts
add column if not exists reposts_count integer not null default 0;

alter table public.community_posts
add column if not exists replies_count integer not null default 0;

alter table public.community_posts
add column if not exists views_count integer not null default 0;

alter table public.community_posts
add column if not exists category text not null default 'Barchasi';

alter table public.community_posts
add column if not exists module_id uuid null references public.modules(id) on delete set null;

alter table public.community_posts
add column if not exists topic_id uuid null references public.topics(id) on delete set null;

alter table public.community_posts
alter column title set default '';

update public.community_posts
set title = ''
where title is null;

alter table public.community_posts enable row level security;

grant select, insert, update, delete on public.community_posts to authenticated;
grant select, insert, delete on public.post_likes to authenticated;
grant select, insert, delete on public.post_reposts to authenticated;
grant select, insert, update, delete on public.post_replies to authenticated;
grant select, insert, delete on public.reply_likes to authenticated;
grant select, insert, delete on public.post_bookmarks to authenticated;

drop policy if exists "community_posts_select_all" on public.community_posts;
drop policy if exists "community_posts_select_authenticated" on public.community_posts;
create policy "community_posts_select_authenticated"
on public.community_posts for select
to authenticated
using (coalesce(is_blocked, false) = false or public.is_admin());

drop policy if exists "community_posts_insert_own" on public.community_posts;
drop policy if exists "Allow users to create posts" on public.community_posts;
create policy "community_posts_insert_own"
on public.community_posts for insert
to authenticated
with check (auth.uid() = author_id);

drop policy if exists "community_posts_update_own" on public.community_posts;
drop policy if exists "Allow author to delete/update posts" on public.community_posts;
create policy "community_posts_update_own"
on public.community_posts for update
to authenticated
using (auth.uid() = author_id or public.is_admin())
with check (auth.uid() = author_id or public.is_admin());

drop policy if exists "community_posts_delete_own" on public.community_posts;
create policy "community_posts_delete_own"
on public.community_posts for delete
to authenticated
using (auth.uid() = author_id or public.is_admin());

alter table public.post_likes enable row level security;
alter table public.post_reposts enable row level security;
alter table public.post_replies enable row level security;
alter table public.reply_likes enable row level security;
alter table public.post_bookmarks enable row level security;

drop policy if exists "post_likes_select_all" on public.post_likes;
drop policy if exists "post_likes_select_authenticated" on public.post_likes;
create policy "post_likes_select_authenticated"
on public.post_likes for select
to authenticated
using (true);

drop policy if exists "post_likes_insert_own" on public.post_likes;
create policy "post_likes_insert_own"
on public.post_likes for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "post_likes_update_own" on public.post_likes;
create policy "post_likes_update_own"
on public.post_likes for update
to authenticated
using (auth.uid() = user_id or public.is_admin())
with check (auth.uid() = user_id or public.is_admin());

drop policy if exists "post_likes_delete_own" on public.post_likes;
create policy "post_likes_delete_own"
on public.post_likes for delete
to authenticated
using (auth.uid() = user_id or public.is_admin());

drop policy if exists "post_reposts_select_all" on public.post_reposts;
drop policy if exists "post_reposts_select_authenticated" on public.post_reposts;
create policy "post_reposts_select_authenticated"
on public.post_reposts for select
to authenticated
using (true);

drop policy if exists "post_reposts_insert_own" on public.post_reposts;
create policy "post_reposts_insert_own"
on public.post_reposts for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "post_reposts_delete_own" on public.post_reposts;
create policy "post_reposts_delete_own"
on public.post_reposts for delete
to authenticated
using (auth.uid() = user_id or public.is_admin());

drop policy if exists "post_replies_select_all" on public.post_replies;
drop policy if exists "post_replies_select_authenticated" on public.post_replies;
create policy "post_replies_select_authenticated"
on public.post_replies for select
to authenticated
using (true);

drop policy if exists "post_replies_insert_own" on public.post_replies;
create policy "post_replies_insert_own"
on public.post_replies for insert
to authenticated
with check (auth.uid() = author_id);

drop policy if exists "post_replies_update_own" on public.post_replies;
create policy "post_replies_update_own"
on public.post_replies for update
to authenticated
using (auth.uid() = author_id or public.is_admin())
with check (auth.uid() = author_id or public.is_admin());

drop policy if exists "post_replies_delete_own" on public.post_replies;
create policy "post_replies_delete_own"
on public.post_replies for delete
to authenticated
using (auth.uid() = author_id or public.is_admin());

drop policy if exists "reply_likes_select_all" on public.reply_likes;
drop policy if exists "reply_likes_select_authenticated" on public.reply_likes;
create policy "reply_likes_select_authenticated"
on public.reply_likes for select
to authenticated
using (true);

drop policy if exists "reply_likes_insert_own" on public.reply_likes;
create policy "reply_likes_insert_own"
on public.reply_likes for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "reply_likes_delete_own" on public.reply_likes;
create policy "reply_likes_delete_own"
on public.reply_likes for delete
to authenticated
using (auth.uid() = user_id or public.is_admin());

drop policy if exists "post_bookmarks_select_own" on public.post_bookmarks;
create policy "post_bookmarks_select_own"
on public.post_bookmarks for select
to authenticated
using (auth.uid() = user_id or public.is_admin());

drop policy if exists "post_bookmarks_insert_own" on public.post_bookmarks;
create policy "post_bookmarks_insert_own"
on public.post_bookmarks for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "post_bookmarks_delete_own" on public.post_bookmarks;
create policy "post_bookmarks_delete_own"
on public.post_bookmarks for delete
to authenticated
using (auth.uid() = user_id or public.is_admin());
