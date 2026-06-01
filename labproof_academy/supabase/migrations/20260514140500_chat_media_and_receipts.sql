alter table public.profiles
add column if not exists telegram_chat_id text,
add column if not exists telegram_user_id text,
add column if not exists telegram_username text,
add column if not exists telegram_last_seen_at timestamptz;

alter table public.admin_inbox_messages
add column if not exists message_kind text not null default 'text'
check (message_kind in ('text', 'image', 'video', 'video_note', 'voice', 'audio', 'document', 'sticker')),
add column if not exists attachment_url text,
add column if not exists attachment_name text,
add column if not exists attachment_mime text,
add column if not exists attachment_size bigint,
add column if not exists admin_read_at timestamptz,
add column if not exists admin_seen_notified_at timestamptz,
add column if not exists recipient_read_at timestamptz;

create index if not exists admin_inbox_messages_source_created_idx
on public.admin_inbox_messages (source, created_at desc);

alter table public.notifications
add column if not exists message_kind text not null default 'text'
check (message_kind in ('text', 'image', 'video', 'video_note', 'voice', 'audio', 'document', 'sticker')),
add column if not exists attachment_url text,
add column if not exists attachment_name text,
add column if not exists attachment_mime text,
add column if not exists attachment_size bigint,
add column if not exists reply_to_inbox_message_id uuid references public.admin_inbox_messages(id) on delete set null;

create index if not exists notifications_reply_lookup_idx
on public.notifications (reply_to_inbox_message_id);

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'chat-attachments',
  'chat-attachments',
  true,
  31457280,
  array[
    'image/png',
    'image/jpeg',
    'image/webp',
    'image/gif',
    'video/mp4',
    'video/quicktime',
    'video/webm',
    'audio/ogg',
    'audio/mpeg',
    'audio/wav',
    'audio/x-m4a',
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'text/plain'
  ]
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "chat_attachments_public_read" on storage.objects;
create policy "chat_attachments_public_read"
on storage.objects for select
using (bucket_id = 'chat-attachments');

drop policy if exists "chat_attachments_authenticated_insert" on storage.objects;
create policy "chat_attachments_authenticated_insert"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'chat-attachments'
);

drop policy if exists "chat_attachments_authenticated_update" on storage.objects;
create policy "chat_attachments_authenticated_update"
on storage.objects for update to authenticated
using (
  bucket_id = 'chat-attachments'
)
with check (
  bucket_id = 'chat-attachments'
);

drop policy if exists "chat_attachments_authenticated_delete" on storage.objects;
create policy "chat_attachments_authenticated_delete"
on storage.objects for delete to authenticated
using (
  bucket_id = 'chat-attachments'
);
