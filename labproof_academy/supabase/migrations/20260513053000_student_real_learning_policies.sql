create policy "questions_select_for_published_content"
on public.quiz_questions for select
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.topics t
    join public.modules m on m.id = t.module_id
    where t.id = quiz_questions.topic_id
      and t.is_published = true
      and m.is_published = true
  )
  or exists (
    select 1
    from public.modules m
    where m.id = quiz_questions.module_id
      and m.is_published = true
  )
);

create policy "results_write_self"
on public.module_results for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());
