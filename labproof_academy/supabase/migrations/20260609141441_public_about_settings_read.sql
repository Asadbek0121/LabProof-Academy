create table if not exists public.public_app_settings (
  id uuid primary key default gen_random_uuid(),
  section text not null,
  key text not null,
  value jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  updated_at timestamptz not null default now(),
  unique (section, key)
);

alter table public.public_app_settings enable row level security;

grant select on public.public_app_settings to anon, authenticated;

drop policy if exists "public_app_settings_read_active" on public.public_app_settings;
create policy "public_app_settings_read_active"
on public.public_app_settings for select
using (is_active = true);

insert into public.public_app_settings (section, key, value)
values
  (
    'settings',
    'social_links',
    '{"telegram":"https://t.me/labproofacademy","instagram":"https://instagram.com/labproofacademy","youtube":"https://youtube.com/@labproofacademy","facebook":"https://facebook.com/labproofacademy"}'::jsonb
  ),
  (
    'legal',
    'legal_terms',
    '{"text":"LabProof Academy ilovasidan foydalanish orqali siz taʼlim materiallaridan qonuniy foydalanish, hisob maʼlumotlarini himoya qilish va platforma qoidalariga rioya qilishga rozilik bildirasiz. Premium obunalar toʼlov tasdiqlangandan keyin faollashadi."}'::jsonb
  ),
  (
    'legal',
    'legal_privacy',
    '{"text":"LabProof Academy telefon raqami, profil maʼlumotlari, progress, test natijalari va texnik maʼlumotlardan faqat xizmatni ishlatish, xavfsizlik, qoʼllab-quvvatlash va toʼlovlarni boshqarish uchun foydalanadi."}'::jsonb
  )
on conflict (section, key) do nothing;
