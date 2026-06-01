alter table public.telegram_verifications
add column if not exists name_confirmed boolean not null default false;
