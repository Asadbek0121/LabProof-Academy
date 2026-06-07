alter table public.admin_inbox_messages
add column if not exists metadata jsonb not null default '{}'::jsonb;

create index if not exists admin_inbox_messages_metadata_gin_idx
on public.admin_inbox_messages using gin (metadata);
