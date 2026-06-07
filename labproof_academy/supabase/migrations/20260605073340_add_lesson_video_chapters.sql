alter table public.lessons
  add column if not exists chapters jsonb not null default '[]'::jsonb;

do $$
begin
  alter table public.lessons
    add constraint lessons_chapters_is_array
    check (jsonb_typeof(chapters) = 'array');
exception
  when duplicate_object then
    null;
end
$$;

comment on column public.lessons.chapters is
  'Video lesson chapter markers shown in the student app. Format: [{"time_seconds":0,"title":"Kirish"}].';
