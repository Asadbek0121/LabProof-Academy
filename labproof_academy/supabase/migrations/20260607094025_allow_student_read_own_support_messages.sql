grant select, insert on public.admin_inbox_messages to authenticated;

drop policy if exists "admin_inbox_student_select_own" on public.admin_inbox_messages;
create policy "admin_inbox_student_select_own"
on public.admin_inbox_messages for select
to authenticated
using (
  sender_user_id = auth.uid()
  and source = 'student_app'
);
