create table if not exists public.admin_inbox_messages (
  id uuid primary key default gen_random_uuid(),
  source text not null default 'student_app'
    check (source in ('student_app', 'telegram', 'system')),
  sender_user_id uuid references auth.users(id) on delete set null,
  sender_name text not null default '',
  sender_phone text not null default '',
  telegram_chat_id text,
  subject text not null,
  body text not null,
  is_read boolean not null default false,
  admin_reply text,
  replied_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists admin_inbox_messages_created_idx
on public.admin_inbox_messages (created_at desc);

create index if not exists admin_inbox_messages_unread_idx
on public.admin_inbox_messages (is_read, created_at desc);

alter table public.admin_inbox_messages enable row level security;

drop policy if exists "admin_inbox_admin_all" on public.admin_inbox_messages;
create policy "admin_inbox_admin_all"
on public.admin_inbox_messages for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "admin_inbox_student_insert" on public.admin_inbox_messages;
create policy "admin_inbox_student_insert"
on public.admin_inbox_messages for insert
to authenticated
with check (
  sender_user_id = auth.uid()
  and source = 'student_app'
);
