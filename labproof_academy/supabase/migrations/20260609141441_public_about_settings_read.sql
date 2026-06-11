grant select on public.admin_settings to anon, authenticated;

drop policy if exists "admin_settings_public_about_read" on public.admin_settings;
create policy "admin_settings_public_about_read"
on public.admin_settings for select
using (
  section in ('settings', 'legal', 'about')
  and key in (
    'social_links',
    'legal_terms',
    'legal_privacy',
    'app_about',
    'contact_info'
  )
);
