create table if not exists public.notification_conversations (
  id uuid primary key default gen_random_uuid(),
  source text not null check (source in ('telegram', 'student_app', 'system')),
  participant_user_id uuid references auth.users(id) on delete set null,
  telegram_chat_id text,
  title text not null default '',
  is_online boolean not null default false,
  typing_at timestamptz,
  last_message_at timestamptz not null default now(),
  unread_admin_count int not null default 0,
  unread_student_count int not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.notification_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.notification_conversations(id) on delete cascade,
  sender_user_id uuid references auth.users(id) on delete set null,
  sender_type text not null check (sender_type in ('admin', 'student', 'bot', 'telegram')),
  message_kind text not null default 'text' check (message_kind in ('text', 'image', 'voice', 'video', 'round_video', 'file', 'pdf', 'document')),
  body text,
  media_id uuid references public.media_library(id) on delete set null,
  attachment_url text,
  attachment_name text,
  attachment_size bigint,
  duration numeric,
  read_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists notification_conversations_last_message_idx
on public.notification_conversations (last_message_at desc);

create index if not exists notification_conversations_participant_idx
on public.notification_conversations (participant_user_id);

create index if not exists notification_conversations_telegram_idx
on public.notification_conversations (telegram_chat_id);

create index if not exists notification_messages_conversation_created_idx
on public.notification_messages (conversation_id, created_at);

alter table public.notification_conversations enable row level security;
alter table public.notification_messages enable row level security;

grant select, insert, update on public.notification_conversations to authenticated;
grant select, insert, update on public.notification_messages to authenticated;

drop policy if exists "notification_conversations_admin_all" on public.notification_conversations;
create policy "notification_conversations_admin_all"
on public.notification_conversations for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "notification_conversations_participant_select" on public.notification_conversations;
create policy "notification_conversations_participant_select"
on public.notification_conversations for select
using (participant_user_id = auth.uid() or public.is_admin());

drop policy if exists "notification_messages_admin_all" on public.notification_messages;
create policy "notification_messages_admin_all"
on public.notification_messages for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "notification_messages_participant_select" on public.notification_messages;
create policy "notification_messages_participant_select"
on public.notification_messages for select
using (
  public.is_admin()
  or exists (
    select 1
    from public.notification_conversations c
    where c.id = notification_messages.conversation_id
      and c.participant_user_id = auth.uid()
  )
);
