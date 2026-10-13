-- Shop checkout, step 1 (2/4): weight and shipping policy on every sellable product
-- (docs/checkout-shop.md, sections 3.4 and 5.1). Safe to run more than once.
--
-- weight_g: grams of one base unit; null falls back to shop_settings.default_weight_g.
-- ship_policy: 'in_store_only' items cannot be delivered, only picked up at the shop.

alter table public.products
  add column if not exists weight_g    int check (weight_g is null or weight_g between 1 and 50000),
  add column if not exists ship_policy text not null default 'shippable'
    check (ship_policy in ('shippable', 'in_store_only'));

notify pgrst, 'reload schema';
