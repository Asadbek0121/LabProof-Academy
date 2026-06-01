alter table public.topics
add column if not exists cover_url text not null default '',
add column if not exists duration_seconds int not null default 0;
