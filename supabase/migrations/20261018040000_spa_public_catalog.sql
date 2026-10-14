-- Customer UI, step 6: the public spa price list (docs/giao-dien-khach-hang.md, 3.5 and 5.2).
--
--  spa_public_catalog(p_branch)  what the website shows without signing in:
--    species   the animals the spa serves, each with its weight brackets
--    services  active services: type 'all' (one general price) or 'by_weight' (a price per species and
--              bracket; a branch override wins over the shared price)
--    combos    sellable combos (status 1, active, not marked "coming soon"), with their service names
--  A service or combo with no species rows is for every species (the rule save_appointment applies),
--  so `species_ids` always lists them explicitly. Prices are what a customer sees; the real price is
--  still settled at the counter. Safe to run more than once.

create or replace function public.spa_public_catalog(p_branch uuid default null) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with sp as (
    select s.id, s.name
    from public.species s
    where s.is_active
  ),
  svc as (
    select v.*
    from public.pet_services v
    where v.is_active
  ),
  cmb as (
    select c.*
    from public.pet_service_combos c
    where c.is_active and c.status = 1 and coalesce(c.mark_as_id, '4') <> '3'
  ),
  svc_species as (
    select v.id as service_id,
           coalesce(
             (select jsonb_agg(ss.species_id order by sp.name)
              from public.service_species ss join sp on sp.id = ss.species_id
              where ss.service_id = v.id),
             '[]'::jsonb
           ) as listed,
           (select jsonb_agg(sp.id order by sp.name) from sp) as every
    from svc v
  ),
  cmb_species as (
    select c.id as combo_id,
           coalesce(
             (select jsonb_agg(cs.species_id order by sp.name)
              from public.combo_species cs join sp on sp.id = cs.species_id
              where cs.combo_id = c.id),
             '[]'::jsonb
           ) as listed,
           (select jsonb_agg(sp.id order by sp.name) from sp) as every
    from cmb c
  ),
  prices as (
    select distinct on (pr.species_id, pr.service_id, pr.bracket_id)
           pr.species_id, pr.service_id, pr.bracket_id, pr.price
    from public.pet_service_prices pr
    join svc on svc.id = pr.service_id and svc.type = 'by_weight'
    where pr.branch_id is null or pr.branch_id = p_branch
    order by pr.species_id, pr.service_id, pr.bracket_id, (pr.branch_id is not null) desc
  )
  select jsonb_build_object(
    'species', coalesce((
      select jsonb_agg(
               jsonb_build_object(
                 'id', sp.id,
                 'name', sp.name,
                 'brackets', coalesce((
                   select jsonb_agg(
                            jsonb_build_object('id', b.id, 'label', b.label, 'min_kg', b.min_kg, 'max_kg', b.max_kg)
                            order by b.min_kg)
                   from public.weight_brackets b where b.species_id = sp.id
                 ), '[]'::jsonb)
               )
               order by sp.name)
      from sp
    ), '[]'::jsonb),
    'services', coalesce((
      select jsonb_agg(
               jsonb_build_object(
                 'id', v.id,
                 'name', v.name,
                 'description', v.description,
                 'type', coalesce(v.type, 'all'),
                 'duration_minutes', v.duration_minutes,
                 'general_price', v.general_price,
                 'species_ids', case when jsonb_array_length(ss.listed) = 0 then coalesce(ss.every, '[]'::jsonb) else ss.listed end,
                 'prices', coalesce((
                   select jsonb_agg(jsonb_build_object(
                            'species_id', p.species_id, 'bracket_id', p.bracket_id, 'price', p.price))
                   from prices p where p.service_id = v.id
                 ), '[]'::jsonb)
               )
               order by v.name)
      from svc v join svc_species ss on ss.service_id = v.id
    ), '[]'::jsonb),
    'combos', coalesce((
      select jsonb_agg(
               jsonb_build_object(
                 'id', c.id,
                 'name', c.name,
                 'description', c.description,
                 'price', c.price,
                 'origin_price', c.origin_price,
                 'duration_minutes', c.duration_minutes,
                 'mark', c.mark_as_id,
                 'species_ids', case when jsonb_array_length(cs.listed) = 0 then coalesce(cs.every, '[]'::jsonb) else cs.listed end,
                 'service_names', coalesce((
                   select jsonb_agg(v.name order by v.name)
                   from public.combo_services x join public.pet_services v on v.id = x.service_id
                   where x.combo_id = c.id
                 ), '[]'::jsonb)
               )
               order by c.name)
      from cmb c join cmb_species cs on cs.combo_id = c.id
    ), '[]'::jsonb)
  );
$$;

revoke execute on function public.spa_public_catalog(uuid) from public;
grant execute on function public.spa_public_catalog(uuid) to anon, authenticated;

notify pgrst, 'reload schema';
