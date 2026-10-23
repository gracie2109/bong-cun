-- Mock data for a SECOND branch, to try the multi-branch dashboard and the "all branches" scope.
--
-- Not a migration: nothing runs it automatically. Paste it into the Supabase SQL editor, or
--   psql "$DATABASE_URL" -f supabase/mock/mock-branch-seed.sql
--
-- Everything it writes is tagged so it can be removed again with mock-branch-cleanup.sql:
--   * a branch with code 'MOCK' (every operational row hangs off that branch),
--   * customers named '[MOCK] ...' with phones 0990000001..0990000009 (and their pets).
-- It never changes an existing row and creates no products, services or other catalogue rows (the
-- catalogue is shared with the public shop). It reuses the first tracked products, species, kennel type
-- and vaccine type it finds; a part with nothing to reuse is skipped with a notice.
--
-- The whole script is one transaction: if anything fails nothing is written. Running it twice is refused.
begin;

do $seed$
declare
  v_branch   uuid;
  v_user     uuid;
  v_species  uuid;
  v_type     uuid;
  v_vaccine  uuid;
  v_products uuid[];
  v_cust     uuid[] := '{}';
  v_pets     uuid[] := '{}';
  v_id       uuid;
  v_cust_id  uuid;
  v_inv      uuid;
  v_stay     uuid;
  v_kennel   uuid[] := '{}';
  v_day      int;
  i          int;
begin
  if exists (select 1 from public.branches where code = 'MOCK') then
    raise exception 'The MOCK branch already exists. Run mock-branch-cleanup.sql first.';
  end if;

  -- The rows need an author; use the oldest account (the owner's).
  select u.id into v_user from public.users u order by u.created_at limit 1;
  if v_user is null then raise exception 'No user account found to attribute the mock rows to.'; end if;
  select id into v_species from public.species order by created_at limit 1;
  select id into v_type from public.kennel_types order by created_at limit 1;
  select id into v_vaccine from public.vaccine_types where kind = 'vaccine' order by created_at limit 1;
  select coalesce(array_agg(id order by name), '{}') into v_products
  from (select id, name from public.products where track_stock and is_active order by name limit 6) p;

  insert into public.branches (code, name) values ('MOCK', 'Chi nhánh mẫu (MOCK)') returning id into v_branch;

  -- Customers and pets (tagged by name and phone).
  for i in 1..4 loop
    insert into public.customers (full_name, phone) values ('[MOCK] Khách ' || i, '099000000' || i) returning id into v_cust_id;
    v_cust := v_cust || v_cust_id;
    if v_species is not null then
      insert into public.pets (species_id, name) values (v_species, '[MOCK] Bé ' || i) returning id into v_id;
      insert into public.pet_owners (pet_id, customer_id) values (v_id, v_cust_id);
      v_pets := v_pets || v_id;
    end if;
  end loop;

  -- Stock: sold out (had a lot), low, expiring, expired, healthy; the sixth product never had a lot.
  -- Lots start full so the sales below can draw from them; the final quantities are set afterwards.
  for i in 1..least(coalesce(array_length(v_products, 1), 0), 5) loop
    insert into public.stock_lots (branch_id, product_id, lot_no, qty_on_hand, unit_cost, expiry_date)
    values (v_branch, v_products[i], 'MOCK-' || i, 50, 30000,
            case i when 3 then current_date + 20 when 4 then current_date - 5 else null end);
  end loop;
  if array_length(v_products, 1) >= 2 then
    insert into public.stock_thresholds (branch_id, product_id, min_qty) values (v_branch, v_products[2], 10);
  end if;

  -- Counter-style sales, one a day for the last 10 days (online channel: no cash shift needed).
  if array_length(v_products, 1) >= 5 then
    for v_day in 0..9 loop
      insert into public.invoices (code, branch_id, status, subtotal, total, created_by, channel, created_at, customer_id)
      values ('MOCK-INV-' || lpad(v_day::text, 2, '0'), v_branch, 'paid', 150000 + v_day * 10000, 150000 + v_day * 10000,
              v_user, 'online', now() - make_interval(days => v_day, hours => 2), v_cust[1 + v_day % 4])
      returning id into v_inv;
      insert into public.invoice_lines (invoice_id, line_no, item_type, product_id, name, qty, unit_price, amount)
      values (v_inv, 1, 'product', v_products[5], 'Mock sale', 1, 150000 + v_day * 10000, 150000 + v_day * 10000);
      insert into public.payments (invoice_id, method, amount)
      values (v_inv, case when v_day % 3 = 0 then 'transfer' else 'cash' end, 150000 + v_day * 10000);
    end loop;
  end if;

  -- Final stock levels.
  if array_length(v_products, 1) >= 5 then
    update public.stock_lots set qty_on_hand = 0 where branch_id = v_branch and product_id = v_products[1];
    update public.stock_lots set qty_on_hand = 3 where branch_id = v_branch and product_id = v_products[2];
    update public.stock_lots set qty_on_hand = 8 where branch_id = v_branch and product_id = v_products[3];
    update public.stock_lots set qty_on_hand = 4 where branch_id = v_branch and product_id = v_products[4];
  end if;

  -- Online orders: two delivered today (packed two days ago), two still on the way, one returned, one
  -- cancelled, and two waiting for confirmation.
  for i in 1..7 loop
    v_inv := null;
    if i <= 6 then
      insert into public.invoices (code, branch_id, status, subtotal, total, created_by, channel, created_at,
                                   cancelled_at, customer_id)
      values ('MOCK-ORD-INV-' || i, v_branch,
              case when i >= 5 then 'cancelled' else 'unpaid' end,
              200000, 200000, v_user, 'online', now() - interval '2 days',
              case when i >= 5 then now() - interval '1 day' end, v_cust[1 + i % 4])
      returning id into v_inv;
    end if;
    insert into public.shop_orders (code, branch_id, user_id, customer_id, status, delivery_method, payment_method,
                                    receiver_name, receiver_phone, ship_street, ghn_district_id, ghn_ward_code,
                                    subtotal, total, invoice_id)
    values ('MOCK-ORD-' || i, v_branch, v_user, v_cust[1 + i % 4],
            case when i <= 2 then 'shipping' when i <= 4 then 'shipping' when i = 5 then 'returned'
                 when i = 6 then 'cancelled' else 'pending' end,
            'delivery', 'cod', '[MOCK] Khách ' || (1 + i % 4), '099000000' || (1 + i % 4), '1 Đường mẫu', 1, '1',
            200000, 200000, v_inv);
    -- The first two are delivered today: the invoice turns paid now and the cash is collected.
    if i <= 2 then
      update public.invoices set status = 'paid' where id = v_inv;
      insert into public.payments (invoice_id, method, amount) values (v_inv, 'cod', 200000);
      update public.shop_orders set status = 'completed' where invoice_id = v_inv;
    end if;
  end loop;
  insert into public.shop_orders (code, branch_id, user_id, customer_id, status, delivery_method, payment_method,
                                  receiver_name, receiver_phone, ship_street, ghn_district_id, ghn_ward_code,
                                  subtotal, total)
  values ('MOCK-ORD-8', v_branch, v_user, v_cust[1], 'pending', 'delivery', 'cod', '[MOCK] Khách 1', '0990000001',
          '2 Đường mẫu', 1, '1', 120000, 120000);

  -- Vaccines: two overdue and one due this week, given at the MOCK branch.
  if v_vaccine is not null and cardinality(v_pets) >= 3 then
    insert into public.vaccinations (pet_id, vaccine_type_id, branch_id, given_on, next_due_on) values
      (v_pets[1], v_vaccine, v_branch, current_date - 380, current_date - 15),
      (v_pets[2], v_vaccine, v_branch, current_date - 400, current_date - 35),
      (v_pets[3], v_vaccine, v_branch, current_date - 360, current_date + 4);
  else
    raise notice 'No vaccine type or species found: vaccine reminders skipped.';
  end if;

  -- Boarding: three kennels; a big one with two pets sharing it, one in a small kennel that is overdue.
  if v_type is not null and cardinality(v_pets) >= 3 then
    for i in 1..3 loop
      insert into public.kennels (branch_id, kennel_type_id, code) values (v_branch, v_type, 'MOCK-K' || i)
      returning id into v_id;
      v_kennel := v_kennel || v_id;
    end loop;
    insert into public.boarding_stays (code, branch_id, customer_id, customer_name, customer_phone, status,
                                       planned_in_at, planned_out_at, checked_in_at, created_by)
    values ('MOCK-STAY-1', v_branch, v_cust[1], '[MOCK] Khách 1', '0990000001', 'checked_in',
            now() - interval '2 days', now() + interval '3 days', now() - interval '2 days', v_user)
    returning id into v_stay;
    insert into public.boarding_stay_pets (stay_id, branch_id, line_no, pet_id, pet_name, kennel_type_id, kennel_id,
                                           nights, charged_nights, est_night_price)
    values (v_stay, v_branch, 1, v_pets[1], '[MOCK] Bé 1', v_type, v_kennel[1],
            daterange(current_date - 2, current_date + 3), 5, 100000),
           (v_stay, v_branch, 2, v_pets[2], '[MOCK] Bé 2', v_type, v_kennel[1],
            daterange(current_date - 2, current_date + 3), 5, 100000);
    insert into public.boarding_stays (code, branch_id, customer_id, customer_name, customer_phone, status,
                                       planned_in_at, planned_out_at, checked_in_at, created_by)
    values ('MOCK-STAY-2', v_branch, v_cust[3], '[MOCK] Khách 3', '0990000003', 'checked_in',
            now() - interval '4 days', now() - interval '3 hours', now() - interval '4 days', v_user)
    returning id into v_stay;
    insert into public.boarding_stay_pets (stay_id, branch_id, line_no, pet_id, pet_name, kennel_type_id, kennel_id,
                                           nights, charged_nights, est_night_price)
    values (v_stay, v_branch, 1, v_pets[3], '[MOCK] Bé 3', v_type, v_kennel[2],
            daterange(current_date - 4, current_date + 1), 5, 100000);
  else
    raise notice 'No kennel type found: boarding skipped.';
  end if;

  raise notice 'MOCK branch created: %', v_branch;
end
$seed$;

commit;

-- What was created (counts per table for the MOCK branch).
select 'invoices' as what, count(*) from public.invoices i join public.branches b on b.id = i.branch_id where b.code = 'MOCK'
union all select 'shop_orders', count(*) from public.shop_orders o join public.branches b on b.id = o.branch_id where b.code = 'MOCK'
union all select 'stock_lots', count(*) from public.stock_lots l join public.branches b on b.id = l.branch_id where b.code = 'MOCK'
union all select 'vaccinations', count(*) from public.vaccinations v join public.branches b on b.id = v.branch_id where b.code = 'MOCK'
union all select 'kennels', count(*) from public.kennels k join public.branches b on b.id = k.branch_id where b.code = 'MOCK'
union all select 'customers', count(*) from public.customers where full_name like '[MOCK] %';
