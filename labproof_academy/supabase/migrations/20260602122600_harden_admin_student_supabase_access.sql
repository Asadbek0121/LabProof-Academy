-- Harden admin/student access after wiring the admin panel and Flutter app to Supabase.

-- Community app compatibility: the Flutter app reads these fields directly.
alter table if exists public.community_posts
  add column if not exists category text not null default 'Barchasi',
  add column if not exists comments_count integer not null default 0,
  add column if not exists module_id uuid references public.modules(id) on delete set null,
  add column if not exists topic_id uuid references public.topics(id) on delete set null;

create index if not exists idx_community_posts_category_created
  on public.community_posts(category, created_at desc);

create index if not exists idx_community_posts_module
  on public.community_posts(module_id);

create index if not exists idx_community_posts_topic
  on public.community_posts(topic_id);

-- Legacy subscription extension tables were created without RLS.
alter table if exists public.subscription_plans enable row level security;
alter table if exists public.user_subscriptions enable row level security;

drop policy if exists "subscription_plans_active_read" on public.subscription_plans;
create policy "subscription_plans_active_read"
on public.subscription_plans for select
to anon, authenticated
using (is_active = true or public.is_admin());

drop policy if exists "subscription_plans_admin_all" on public.subscription_plans;
create policy "subscription_plans_admin_all"
on public.subscription_plans for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "user_subscriptions_self_or_admin_select" on public.user_subscriptions;
create policy "user_subscriptions_self_or_admin_select"
on public.user_subscriptions for select
to authenticated
using (user_id = auth.uid() or public.is_admin());

drop policy if exists "user_subscriptions_admin_all" on public.user_subscriptions;
create policy "user_subscriptions_admin_all"
on public.user_subscriptions for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- Community tables are for signed-in students/admins, not anonymous public writes.
alter table if exists public.community_posts enable row level security;
alter table if exists public.post_likes enable row level security;
alter table if exists public.post_reposts enable row level security;
alter table if exists public.post_replies enable row level security;
alter table if exists public.reply_likes enable row level security;
alter table if exists public.post_bookmarks enable row level security;
alter table if exists public.community_notifications enable row level security;

drop policy if exists "community_posts_select_all" on public.community_posts;
create policy "community_posts_select_authenticated"
on public.community_posts for select
to authenticated
using (true);

drop policy if exists "community_posts_insert_own" on public.community_posts;
create policy "community_posts_insert_own"
on public.community_posts for insert
to authenticated
with check (auth.uid() = author_id);

drop policy if exists "community_posts_update_own" on public.community_posts;
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

drop policy if exists "post_likes_select_all" on public.post_likes;
create policy "post_likes_select_authenticated"
on public.post_likes for select
to authenticated
using (true);

drop policy if exists "post_likes_insert_own" on public.post_likes;
create policy "post_likes_insert_own"
on public.post_likes for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "post_likes_delete_own" on public.post_likes;
create policy "post_likes_delete_own"
on public.post_likes for delete
to authenticated
using (auth.uid() = user_id or public.is_admin());

drop policy if exists "post_reposts_select_all" on public.post_reposts;
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

drop policy if exists "community_notifications_select_own" on public.community_notifications;
create policy "community_notifications_select_own"
on public.community_notifications for select
to authenticated
using (auth.uid() = user_id or public.is_admin());

drop policy if exists "community_notifications_insert_system" on public.community_notifications;
drop policy if exists "community_notifications_admin_insert" on public.community_notifications;
create policy "community_notifications_admin_insert"
on public.community_notifications for insert
to authenticated
with check (public.is_admin());

drop policy if exists "community_notifications_update_own" on public.community_notifications;
create policy "community_notifications_update_own"
on public.community_notifications for update
to authenticated
using (auth.uid() = user_id or public.is_admin())
with check (auth.uid() = user_id or public.is_admin());

-- Explicit Data API grants for the public schema. RLS remains the row-level gate.
grant usage on schema public to anon, authenticated;

grant select on public.app_releases to anon, authenticated;

grant select on public.subscription_plans to anon, authenticated;
grant select on public.user_subscriptions to authenticated;

grant select, insert, update, delete on public.community_posts to authenticated;
grant select, insert, delete on public.post_likes to authenticated;
grant select, insert, delete on public.post_reposts to authenticated;
grant select, insert, update, delete on public.post_replies to authenticated;
grant select, insert, delete on public.reply_likes to authenticated;
grant select, insert, delete on public.post_bookmarks to authenticated;
grant select, insert, update on public.community_notifications to authenticated;

grant select, insert, update, delete on public.profiles to authenticated;
grant select on public.modules, public.topics, public.lessons, public.quiz_questions to authenticated;
grant select, insert, update on public.topic_progress, public.module_results to authenticated;
grant select on public.certificates to authenticated;
grant select, insert, update on public.notifications, public.notification_reads, public.notification_settings to authenticated;

drop policy if exists "profiles_admin_all" on public.profiles;
create policy "profiles_admin_all"
on public.profiles for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "profiles_select_community_authors" on public.profiles;
create policy "profiles_select_community_authors"
on public.profiles for select
to authenticated
using (
  id = auth.uid()
  or public.is_admin()
  or exists (
    select 1 from public.community_posts p
    where p.author_id = profiles.id
  )
  or exists (
    select 1 from public.post_replies r
    where r.author_id = profiles.id
  )
);
