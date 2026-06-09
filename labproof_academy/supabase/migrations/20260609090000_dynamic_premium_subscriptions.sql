-- Dynamic premium subscription system managed from the admin panel.

alter table public.subscription_plans
  add column if not exists name text,
  add column if not exists duration_days integer,
  add column if not exists price numeric(12,2) not null default 0,
  add column if not exists discount_percent integer not null default 0,
  add column if not exists is_popular boolean not null default false,
  add column if not exists features text[] not null default array[
    'Barcha kurslar',
    'Sertifikat',
    'Progress kuzatish',
    'Reklamasiz'
  ],
  add column if not exists sort_order integer not null default 0;

update public.subscription_plans
set
  name = coalesce(nullif(name, ''), title),
  duration_days = coalesce(duration_days, greatest(1, duration_months) * 30),
  discount_percent = greatest(0, least(100, discount_percent))
where name is null
   or btrim(name) = ''
   or duration_days is null;

alter table public.subscription_plans
  alter column name set not null,
  alter column duration_days set not null;

alter table public.subscription_plans
  add constraint subscription_plans_duration_days_check
  check (duration_days > 0) not valid;

alter table public.subscription_plans
  add constraint subscription_plans_discount_percent_check
  check (discount_percent between 0 and 100) not valid;

create table if not exists public.payment_methods (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text not null unique,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.subscription_payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_id uuid not null references public.subscription_plans(id) on delete restrict,
  payment_method_id uuid not null references public.payment_methods(id) on delete restrict,
  amount numeric(12,2) not null default 0,
  currency text not null default 'UZS',
  status text not null default 'pending'
    check (status in ('pending', 'paid', 'failed', 'cancelled', 'refunded')),
  provider_payment_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  paid_at timestamptz
);

create index if not exists subscription_payments_user_created_idx
  on public.subscription_payments(user_id, created_at desc);

create index if not exists subscription_payments_status_idx
  on public.subscription_payments(status);

alter table public.profiles
  add column if not exists is_premium boolean not null default false,
  add column if not exists premium_plan_id uuid references public.subscription_plans(id) on delete set null,
  add column if not exists premium_start_date timestamptz,
  add column if not exists premium_end_date timestamptz;

alter table public.payment_methods enable row level security;
alter table public.subscription_payments enable row level security;

drop policy if exists "payment_methods_active_read" on public.payment_methods;
create policy "payment_methods_active_read"
on public.payment_methods for select
to anon, authenticated
using (is_active = true or public.is_admin());

drop policy if exists "payment_methods_admin_all" on public.payment_methods;
create policy "payment_methods_admin_all"
on public.payment_methods for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "subscription_payments_self_or_admin_select" on public.subscription_payments;
create policy "subscription_payments_self_or_admin_select"
on public.subscription_payments for select
to authenticated
using (user_id = auth.uid() or public.is_admin());

drop policy if exists "subscription_payments_insert_own" on public.subscription_payments;
create policy "subscription_payments_insert_own"
on public.subscription_payments for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "subscription_payments_admin_all" on public.subscription_payments;
create policy "subscription_payments_admin_all"
on public.subscription_payments for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

insert into public.subscription_plans (
  title,
  name,
  duration_months,
  duration_days,
  price_label,
  price,
  discount_percent,
  is_popular,
  is_active,
  features,
  sort_order
)
select
  seed.title,
  seed.name,
  seed.duration_months,
  seed.duration_days,
  seed.price_label,
  seed.price,
  seed.discount_percent,
  seed.is_popular,
  true,
  seed.features,
  seed.sort_order
from (
  values
    (
      '1 oy Premium',
      '1 oy Premium',
      1,
      30,
      '49 000 so‘m',
      49000::numeric,
      0,
      false,
      array['Barcha kurslar','Sertifikat','Progress kuzatish','Reklamasiz'],
      10
    ),
    (
      '3 oy Premium',
      '3 oy Premium',
      3,
      90,
      '129 000 so‘m',
      129000::numeric,
      10,
      true,
      array['Barcha kurslar','Sertifikat','Progress kuzatish','Reklamasiz'],
      20
    ),
    (
      '12 oy Premium',
      '12 oy Premium',
      12,
      365,
      '399 000 so‘m',
      399000::numeric,
      30,
      false,
      array['Barcha kurslar','Sertifikat','Progress kuzatish','Reklamasiz'],
      30
    )
) as seed(
  title,
  name,
  duration_months,
  duration_days,
  price_label,
  price,
  discount_percent,
  is_popular,
  features,
  sort_order
)
where not exists (
  select 1
  from public.subscription_plans p
  where lower(coalesce(p.name, p.title)) = lower(seed.name)
);

insert into public.payment_methods (name, code, is_active, sort_order)
values
  ('Click', 'click', true, 10),
  ('Payme', 'payme', true, 20),
  ('Uzum Bank', 'uzum_bank', true, 30),
  ('Visa / Mastercard', 'card', true, 40)
on conflict (code) do update
set
  name = excluded.name,
  sort_order = excluded.sort_order,
  updated_at = now();

create or replace function public.purchase_subscription(
  p_plan_id uuid,
  p_payment_method_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_plan record;
  v_method record;
  v_payment_id uuid;
begin
  if v_user_id is null then
    raise exception 'authentication_required';
  end if;

  select *
  into v_plan
  from public.subscription_plans
  where id = p_plan_id
    and is_active = true;

  if not found then
    raise exception 'subscription_plan_not_found';
  end if;

  select *
  into v_method
  from public.payment_methods
  where id = p_payment_method_id
    and is_active = true;

  if not found then
    raise exception 'payment_method_not_found';
  end if;

  insert into public.subscription_payments (
    user_id,
    plan_id,
    payment_method_id,
    amount,
    currency,
    status,
    metadata
  )
  values (
    v_user_id,
    p_plan_id,
    p_payment_method_id,
    coalesce(v_plan.price, 0),
    'UZS',
    'pending',
    jsonb_build_object(
      'plan_name', coalesce(v_plan.name, v_plan.title),
      'duration_days', v_plan.duration_days,
      'payment_method', v_method.code
    )
  )
  returning id into v_payment_id;

  return v_payment_id;
end;
$$;

create or replace function public.activate_subscription_from_payment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plan record;
  v_start timestamptz;
  v_end timestamptz;
begin
  if new.status <> 'paid' or (tg_op = 'UPDATE' and old.status = 'paid') then
    return new;
  end if;

  select *
  into v_plan
  from public.subscription_plans
  where id = new.plan_id;

  if not found then
    return new;
  end if;

  v_start := coalesce(new.paid_at, now());
  v_end := v_start + make_interval(days => greatest(1, v_plan.duration_days));

  update public.profiles
  set
    is_premium = true,
    premium_plan_id = new.plan_id,
    premium_start_date = v_start,
    premium_end_date = v_end,
    updated_at = now()
  where id = new.user_id;

  insert into public.user_subscriptions (
    user_id,
    plan_id,
    status,
    starts_at,
    ends_at,
    updated_at
  )
  values (
    new.user_id,
    new.plan_id,
    'active',
    v_start,
    v_end,
    now()
  );

  return new;
end;
$$;

drop trigger if exists activate_subscription_payment_after_change
on public.subscription_payments;

create trigger activate_subscription_payment_after_change
after insert or update of status
on public.subscription_payments
for each row
execute function public.activate_subscription_from_payment();

create or replace function public.confirm_subscription_payment(p_payment_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'admin_required';
  end if;

  update public.subscription_payments
  set
    status = 'paid',
    paid_at = coalesce(paid_at, now())
  where id = p_payment_id;
end;
$$;

grant select on public.subscription_plans to anon, authenticated;
grant select on public.payment_methods to anon, authenticated;
grant select, insert on public.subscription_payments to authenticated;
grant execute on function public.purchase_subscription(uuid, uuid) to authenticated;
grant execute on function public.confirm_subscription_payment(uuid) to authenticated;
