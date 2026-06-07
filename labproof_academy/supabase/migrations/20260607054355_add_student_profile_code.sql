alter table public.profiles
add column if not exists student_code text;

create sequence if not exists public.profile_student_code_seq
  as integer
  start with 1
  increment by 1
  no minvalue
  no maxvalue
  cache 1;

with numbered_profiles as (
  select
    id,
    row_number() over (order by created_at nulls last, id) as code_number
  from public.profiles
  where student_code is null or btrim(student_code) = ''
)
update public.profiles p
set student_code = 'LPA-' || lpad(numbered_profiles.code_number::text, 5, '0')
from numbered_profiles
where p.id = numbered_profiles.id;

select setval(
  'public.profile_student_code_seq',
  greatest(
    1,
    coalesce(
      (
        select max((substring(student_code from 'LPA-([0-9]+)'))::integer)
        from public.profiles
        where student_code ~ '^LPA-[0-9]+$'
      ),
      0
    ) + 1
  ),
  false
);

create or replace function public.assign_profile_student_code()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.student_code is null or btrim(new.student_code) = '' then
    new.student_code :=
      'LPA-' || lpad(nextval('public.profile_student_code_seq')::text, 5, '0');
  end if;

  return new;
end;
$$;

drop trigger if exists assign_profile_student_code_before_insert
on public.profiles;

create trigger assign_profile_student_code_before_insert
before insert on public.profiles
for each row
execute function public.assign_profile_student_code();

create unique index if not exists profiles_student_code_key
on public.profiles (student_code);

alter table public.profiles
alter column student_code set not null;

grant usage, select on sequence public.profile_student_code_seq to authenticated;
