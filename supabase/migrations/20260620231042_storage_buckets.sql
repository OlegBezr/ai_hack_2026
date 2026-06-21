-- Storage for page media. Two public-read buckets; writes scoped to the
-- authenticated owner. Objects are namespaced by the uploader's uid as the
-- first path segment, e.g. "<uid>/<story_id>/<page_id>.png".

insert into storage.buckets (id, name, public)
values
  ('illustrations', 'illustrations', true),
  ('audio',         'audio',         true)
on conflict (id) do nothing;

-- Public read for both buckets (covers select).
create policy "Public read story media"
  on storage.objects
  as permissive for select
  to anon, authenticated
  using (bucket_id in ('illustrations', 'audio'));

-- Owner-scoped write. Upsert needs INSERT + SELECT + UPDATE; the select above
-- already covers reads, so grant insert/update/delete here.
create policy "Owners upload story media"
  on storage.objects
  as permissive for insert
  to authenticated
  with check (
    bucket_id in ('illustrations', 'audio')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "Owners update own story media"
  on storage.objects
  as permissive for update
  to authenticated
  using (
    bucket_id in ('illustrations', 'audio')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id in ('illustrations', 'audio')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "Owners delete own story media"
  on storage.objects
  as permissive for delete
  to authenticated
  using (
    bucket_id in ('illustrations', 'audio')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
