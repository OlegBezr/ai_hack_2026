-- Edge functions use the service_role key (bypasses RLS) to verify ownership and
-- perform cross-cutting writes (e.g. stamping page.audio_url / page.illustration_url
-- after generating assets). The new Supabase default does not auto-expose new
-- public tables to the Data API roles, so service_role must be granted explicitly.
grant select, insert, update, delete on table "public"."story" to "service_role";
grant select, insert, update, delete on table "public"."page"  to "service_role";
