-- Pet hotel, step 6 (2/2): the public hotel page (docs/khach-san-thu-cung.md, 7).
--
--  boarding_public_catalog(p_branch)  what the website shows without signing in:
--    branch       name and phone of the branch (p_branch, else the first active one)
--    rules        check-in from / check-out by / late-fee hour, as 'HH:MM'
--    kennel_types the public kennel types that have a price, with the nightly price of that branch
--                 (a branch price wins over the shared one) and the species names they take
-- Prices are what a customer sees; staff settle the real amount at check-out. Safe to run more than once.

create or replace function public.boarding_public_catalog(p_branch uuid default null) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch public.branches;
  v_rules  record;
begin
  select * into v_branch
  from public.branches
  where is_active and (p_branch is null or id = p_branch)
  order by created_at
  limit 1;
  if not found then
    return jsonb_build_object('branch', null, 'rules', null, 'kennel_types', '[]'::jsonb);
  end if;
  select * into v_rules from public.boarding_rules(v_branch.id);

  return jsonb_build_object(
    'branch', jsonb_build_object('id', v_branch.id, 'name', v_branch.name, 'phone', v_branch.phone),
    'rules', jsonb_build_object(
      'check_in_from', to_char(v_rules.check_in_from, 'HH24:MI'),
      'check_out_by', to_char(v_rules.check_out_by, 'HH24:MI'),
      'late_half_until', to_char(v_rules.late_half_until, 'HH24:MI')
    ),
    'kennel_types', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', t.id,
        'name', t.name,
        'description', t.description,
        'photo_url', t.photo_url,
        'max_weight_kg', t.max_weight_kg,
        'max_pets', t.max_pets,
        'night_price', public.kennel_night_price(t.id, v_branch.id),
        'extra_pet_night_price', public.kennel_extra_pet_price(t.id, v_branch.id),
        'species', coalesce((
          select jsonb_agg(s.name order by s.name)
          from public.species s where s.id = any(t.species_ids) and s.is_active
        ), '[]'::jsonb)
      ) order by t.sort_order, t.name)
      from public.kennel_types t
      where t.is_active and t.is_public and t.purpose = 'boarding'
        and public.kennel_night_price(t.id, v_branch.id) is not null
        and exists (select 1 from public.kennels k where k.kennel_type_id = t.id and k.branch_id = v_branch.id and k.is_active)
    ), '[]'::jsonb)
  );
end;
$$;

revoke execute on function public.boarding_public_catalog(uuid) from public;
grant execute on function public.boarding_public_catalog(uuid) to anon, authenticated;

notify pgrst, 'reload schema';
