-- Pet hotel, step 6 (1/2): "my boarding stays" for the signed-in web account (docs/khach-san-thu-cung.md, 7).
--
--  my_boarding_stays(p_scope, p_page, p_page_size)  'upcoming' (booked; soonest first), 'current' (checked in) or
--                                                   'past' (checked out, paid, cancelled, no show; newest first).
--                                                   Returns { total, rows }.
--  my_boarding_stay(p_id)                           one stay of mine with the care log entries marked
--                                                   visible_to_customer and the charges.
--
-- The customer only reads; a row never names the staff or the kennel code. Errors (hint): not_signed_in,
-- invalid_scope, not_found. Safe to run more than once.

-- The shape both functions return for a stay (internal).
create or replace function public.my_boarding_stay_json(p_stay public.boarding_stays) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', p_stay.id,
    'code', p_stay.code,
    'status', p_stay.status,
    'planned_in_at', p_stay.planned_in_at,
    'planned_out_at', p_stay.planned_out_at,
    'checked_in_at', p_stay.checked_in_at,
    'checked_out_at', p_stay.checked_out_at,
    'branch_name', b.name,
    'branch_phone', b.phone,
    'est_total', (public.boarding_stay_json(p_stay) ->> 'est_total')::numeric,
    'is_final', p_stay.status in ('checked_out', 'paid'),
    'pets', coalesce((
      select jsonb_agg(jsonb_build_object(
        'pet_name', sp.pet_name,
        'status', sp.status,
        'kennel_type_name', t.name,
        'nights_from', lower(sp.nights),
        'nights_to', upper(sp.nights),
        'charged_nights', sp.charged_nights,
        'feeding', sp.feeding,
        'medication', sp.medication
      ) order by sp.line_no)
      from public.boarding_stay_pets sp
      join public.kennel_types t on t.id = sp.kennel_type_id
      where sp.stay_id = p_stay.id
    ), '[]'::jsonb)
  )
  from public.branches b
  where b.id = p_stay.branch_id;
$$;

revoke execute on function public.my_boarding_stay_json(public.boarding_stays) from public, anon, authenticated;

create or replace function public.my_boarding_stays(
  p_scope text default 'upcoming',
  p_page int default 1,
  p_page_size int default 10
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_cust   uuid := public.my_customer_id();
  v_size   int := least(greatest(coalesce(p_page_size, 10), 1), 50);
  v_offset int := (greatest(coalesce(p_page, 1), 1) - 1) * v_size;
  v_states text[];
  v_total  bigint;
  v_rows   jsonb;
begin
  if auth.uid() is null then
    raise exception 'sign in first' using errcode = '28000', hint = 'not_signed_in';
  end if;
  v_states := case p_scope
    when 'upcoming' then array['booked']
    when 'current' then array['checked_in']
    when 'past' then array['checked_out', 'paid', 'cancelled', 'no_show']
  end;
  if v_states is null then
    raise exception 'unknown scope' using errcode = '22023', hint = 'invalid_scope';
  end if;
  if v_cust is null then
    return jsonb_build_object('total', 0, 'rows', '[]'::jsonb);
  end if;

  select count(*) into v_total
  from public.boarding_stays s where s.customer_id = v_cust and s.status = any(v_states);

  select coalesce(jsonb_agg(public.my_boarding_stay_json(s) order by
           case when p_scope = 'past' then null else s.planned_in_at end asc,
           s.planned_in_at desc), '[]'::jsonb)
  into v_rows
  from (
    select * from public.boarding_stays s
    where s.customer_id = v_cust and s.status = any(v_states)
    order by case when p_scope = 'past' then null else s.planned_in_at end asc, s.planned_in_at desc
    limit v_size offset v_offset
  ) s;

  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

revoke execute on function public.my_boarding_stays(text, int, int) from public, anon;
grant execute on function public.my_boarding_stays(text, int, int) to authenticated;

create or replace function public.my_boarding_stay(p_id uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_cust uuid := public.my_customer_id();
  v_stay public.boarding_stays;
begin
  if auth.uid() is null then
    raise exception 'sign in first' using errcode = '28000', hint = 'not_signed_in';
  end if;
  select * into v_stay from public.boarding_stays where id = p_id and customer_id = v_cust;
  if not found then
    raise exception 'stay not found' using errcode = 'P0002', hint = 'not_found';
  end if;

  return public.my_boarding_stay_json(v_stay) || jsonb_build_object(
    'care_logs', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', l.id,
        'pet_name', sp.pet_name,
        'kind', l.kind,
        'meal_eaten', l.meal_eaten,
        'content', l.content,
        'logged_at', l.logged_at
      ) order by l.logged_at desc)
      from public.boarding_care_logs l
      join public.boarding_stay_pets sp on sp.id = l.stay_pet_id
      where sp.stay_id = v_stay.id and l.visible_to_customer
    ), '[]'::jsonb),
    'charges', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id,
        'pet_name', sp.pet_name,
        'kind', c.kind,
        'name', c.name,
        'qty', c.qty,
        'unit_price', c.unit_price,
        'amount', c.amount
      ) order by c.created_at, c.id)
      from public.boarding_charges c
      left join public.boarding_stay_pets sp on sp.id = c.stay_pet_id
      where c.stay_id = v_stay.id
    ), '[]'::jsonb)
  );
end;
$$;

revoke execute on function public.my_boarding_stay(uuid) from public, anon;
grant execute on function public.my_boarding_stay(uuid) to authenticated;

notify pgrst, 'reload schema';
