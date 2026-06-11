-- Restore subscription plan RLS policies for the dynamic premium billing flow.
-- Without these policies the student app cannot read admin-managed plans.

alter table public.subscription_plans enable row level security;

drop policy if exists "subscription_plans_active_read" on public.subscription_plans;
create policy "subscription_plans_active_read"
on public.subscription_plans for select
to anon, authenticated
using (is_active = true or public.is_admin());

drop policy if exists "subscription_plans_admin_all" on public.subscription_plans;
create policy "subscription_plans_admin_all"
on public.subscription_plans for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

grant select on public.subscription_plans to anon, authenticated;
