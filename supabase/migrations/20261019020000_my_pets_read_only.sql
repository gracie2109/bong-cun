-- Customers can only view their pets (grace, 2026-10-15). The shop adds, edits and removes pets.
--
-- save_my_pet and hide_my_pet are dropped, so the web account can no longer create, edit or hide a pet
-- through the API. my_pets() stays (read-only list). Staff keep using the admin pet screens.
-- Safe to run more than once.

drop function if exists public.save_my_pet(jsonb, uuid);
drop function if exists public.hide_my_pet(uuid);

notify pgrst, 'reload schema';
