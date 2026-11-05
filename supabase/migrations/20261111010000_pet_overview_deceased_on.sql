-- Adds the date a pet died (pets.deceased_on) to the pet_overview view so the pet list export can include it.
-- The new column goes last: create or replace view cannot reorder existing columns. The view keeps its grants.
create or replace view public.pet_overview with (security_invoker = true) as
 select p.id,
    p.name,
    p.species_id,
    s.name as species_name,
    s.icon as species_icon,
    p.breed,
    p.sex,
    p.neutered,
    p.birth_date,
    p.photo_url,
    p.allergies,
    p.behavior_notes,
    p.status,
    p.created_at,
    w.weight_kg,
    w.measured_at as weight_measured_at,
    b.id as bracket_id,
    b.label as bracket_label,
    o.customer_id as owner_id,
    c.full_name as owner_name,
    c.phone as owner_phone,
    ( select count(*) as count
           from public.pet_owners po
          where po.pet_id = p.id and po.to_date is null) as owner_count,
    p.deceased_on
   from public.pets p
     join public.species s on s.id = p.species_id
     left join lateral ( select l.weight_kg, l.measured_at
           from public.pet_weight_logs l
          where l.pet_id = p.id
          order by l.measured_at desc
         limit 1) w on true
     left join public.weight_brackets b on b.species_id = p.species_id and w.weight_kg >= b.min_kg and (b.max_kg is null or w.weight_kg < b.max_kg)
     left join lateral ( select po.customer_id
           from public.pet_owners po
          where po.pet_id = p.id and po.to_date is null
          order by (po.role = 'primary') desc, po.from_date
         limit 1) o on true
     left join public.customers c on c.id = o.customer_id;
