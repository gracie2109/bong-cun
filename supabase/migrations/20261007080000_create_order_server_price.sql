-- create_order no longer trusts the client for money: name, price and duration of every line
-- come from the catalog. Combos use their own price; a service priced "all" uses its general
-- price; a "by_weight" service is priced from the line's species and weight (get_service_price).
-- A service or combo that is hidden, unknown or not priced for that weight rejects the order.
-- p: { name, phone_number, pet_num, scheduled_at,
--      services: [{ id, type: 'combo' | 'service', species_id?, weight_kg? }] }
create or replace function public.create_order(p jsonb) returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_id uuid;
  v_line jsonb;
  v_kind text;
  v_line_id uuid;
  v_name text;
  v_price numeric;
  v_minutes int;
  v_service public.pet_services;
  v_combo public.pet_service_combos;
  v_lines int := 0;
begin
  insert into public.orders (name, phone_number, pet_num, scheduled_at, user_id)
  values (
    p ->> 'name',
    p ->> 'phone_number',
    nullif(p ->> 'pet_num', '')::int,
    nullif(p ->> 'scheduled_at', '')::timestamptz,
    auth.uid()
  )
  returning id into v_id;

  for v_line in select * from jsonb_array_elements(coalesce(p -> 'services', '[]'::jsonb)) loop
    v_kind := v_line ->> 'type';
    v_line_id := (v_line ->> 'id')::uuid;

    if v_kind = 'combo' then
      select * into v_combo from public.pet_service_combos where id = v_line_id and status = 1;
      if not found or v_combo.price is null then
        raise exception 'combo % is not available', v_line_id using errcode = 'P0002';
      end if;
      v_name := v_combo.name;
      v_price := v_combo.price;
      v_minutes := v_combo.duration_minutes;
    elsif v_kind = 'service' then
      select * into v_service from public.pet_services where id = v_line_id and is_show;
      if not found then
        raise exception 'service % is not available', v_line_id using errcode = 'P0002';
      end if;
      if v_service.type = 'by_weight' then
        v_price := public.get_service_price(
          nullif(v_line ->> 'species_id', '')::uuid,
          v_service.id,
          nullif(v_line ->> 'weight_kg', '')::numeric
        );
      else
        v_price := v_service.general_price;
      end if;
      if v_price is null then
        raise exception 'service % has no price for this pet', v_line_id using errcode = 'P0002';
      end if;
      v_name := v_service.name;
      v_minutes := v_service.duration_minutes;
    else
      raise exception 'unknown line type %', v_kind using errcode = '22023';
    end if;

    insert into public.order_items (order_id, service_id, combo_id, name, price, duration_minutes)
    values (
      v_id,
      case when v_kind = 'service' then v_line_id end,
      case when v_kind = 'combo' then v_line_id end,
      v_name,
      v_price,
      v_minutes
    );
    v_lines := v_lines + 1;
  end loop;

  if v_lines = 0 then
    raise exception 'an order needs at least one service' using errcode = '22023';
  end if;

  return v_id;
end;
$$;
