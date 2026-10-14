-- Shop catalog for the public site (docs/giao-dien-khach-hang.md, step 2).
--
--  shop_product_groups   one page of product groups the shop can sell, with search, category (a
--                        parent includes its sub-categories), brand and sort. Each row is the
--                        product_group_json of the group (sellable variants only) plus `in_stock`.
--  shop_related_groups   groups of the same category, for the product page (step 3).
--
-- A group shows only while it is active and has at least one active variant. `in_stock` follows the
-- checkout: a variant that does not track stock always counts, else the online branch must have
-- unreserved stock (shop_available_qty). Prices are the general prices, as the cart charges them.
-- Both functions are security definer only to read stock; they expose nothing the shop does not show.
-- Safe to run more than once.

create or replace function public.shop_product_groups(
  p_search   text default null,
  p_category uuid default null,
  p_brand    uuid default null,
  p_sort     text default 'newest',
  p_limit    int  default 24,
  p_offset   int  default 0
) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with params as (
    select lower(public.immutable_unaccent(nullif(btrim(coalesce(p_search, '')), ''))) as term,
           nullif(btrim(coalesce(p_search, '')), '') as code
  ), candidates as (
    select g.id, g.name, g.created_at
    from public.product_groups g, params
    where g.is_active
      and (p_brand is null or g.brand_id = p_brand)
      and (
        p_category is null
        or g.category_id = p_category
        or g.category_id in (select id from public.product_categories where parent_id = p_category)
      )
      and (
        params.term is null
        or lower(public.immutable_unaccent(g.name)) like '%' || params.term || '%'
        or exists (
          select 1 from public.products p
          where p.group_id = g.id
            and (p.sku ilike '%' || params.code || '%' or p.barcode ilike '%' || params.code || '%')
        )
      )
  ), variants as (
    select p.id, p.group_id, p.price, p.track_stock
    from public.products p
    where p.is_active and p.group_id in (select id from candidates)
  ), stock as (
    select s.product_id, s.qty
    from public.shop_available_qty(array(select id from variants)) s
  ), matched as (
    select c.id, c.name, c.created_at,
           min(v.price) as price_min,
           bool_or(not v.track_stock or coalesce(s.qty, 0) > 0) as in_stock
    from candidates c
    join variants v on v.group_id = c.id
    left join stock s on s.product_id = v.id
    group by c.id, c.name, c.created_at
  ), ordered as (
    select m.*,
           row_number() over (
             order by
               case when p_sort = 'newest' and not m.in_stock then 1 else 0 end,
               case when p_sort = 'price_asc' then m.price_min end asc,
               case when p_sort = 'price_desc' then m.price_min end desc,
               case when p_sort = 'name' then lower(m.name) end asc,
               m.created_at desc,
               m.id
           ) as rn
    from matched m
  ), page as (
    select * from ordered
    where rn > greatest(p_offset, 0) and rn <= greatest(p_offset, 0) + greatest(p_limit, 1)
  )
  select jsonb_build_object(
    'total', (select count(*) from matched),
    'rows', coalesce((
      select jsonb_agg(
        public.product_group_json(page.id, false) || jsonb_build_object('in_stock', page.in_stock)
        order by page.rn
      )
      from page
    ), '[]'::jsonb)
  );
$$;

revoke execute on function public.shop_product_groups(text, uuid, uuid, text, int, int) from public;
grant execute on function public.shop_product_groups(text, uuid, uuid, text, int, int) to anon, authenticated;

create or replace function public.shop_related_groups(p_group uuid, p_limit int default 8) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with source as (
    select category_id from public.product_groups where id = p_group
  ), picked as (
    select g.id, g.created_at
    from public.product_groups g, source
    where g.is_active
      and g.id <> p_group
      and source.category_id is not null
      and g.category_id = source.category_id
      and exists (select 1 from public.products p where p.group_id = g.id and p.is_active)
    order by g.created_at desc, g.id
    limit greatest(least(coalesce(p_limit, 8), 24), 1)
  ), stock as (
    select s.product_id, s.qty
    from public.shop_available_qty(
      array(select p.id from public.products p where p.is_active and p.group_id in (select id from picked))
    ) s
  )
  select coalesce(jsonb_agg(
    public.product_group_json(pk.id, false) || jsonb_build_object('in_stock', coalesce((
      select bool_or(not p.track_stock or coalesce(s.qty, 0) > 0)
      from public.products p
      left join stock s on s.product_id = p.id
      where p.group_id = pk.id and p.is_active
    ), false))
    order by pk.created_at desc, pk.id
  ), '[]'::jsonb)
  from picked pk;
$$;

revoke execute on function public.shop_related_groups(uuid, int) from public;
grant execute on function public.shop_related_groups(uuid, int) to anon, authenticated;

notify pgrst, 'reload schema';
