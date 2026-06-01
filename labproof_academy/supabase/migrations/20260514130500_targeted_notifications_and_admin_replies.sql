alter table public.notifications
add column if not exists target_user_id uuid references auth.users(id) on delete set null;

create index if not exists notifications_target_lookup_idx
on public.notifications (target_role, target_user_id, is_active, created_at desc);

drop policy if exists "notifications_select_student_or_admin" on public.notifications;
create policy "notifications_select_student_or_admin"
on public.notifications for select
to authenticated
using (
  public.is_admin()
  or (
    is_active = true
    and target_role = 'student'
    and (target_user_id is null or target_user_id = auth.uid())
  )
);

alter table public.admin_inbox_messages
add column if not exists telegram_chat_id text;

alter table public.admin_inbox_messages
add column if not exists admin_reply text;

alter table public.admin_inbox_messages
add column if not exists replied_at timestamptz;
