-- Shop checkout, step 6 (1/3): invoices of online orders (docs/checkout-shop.md, section 3.6).
-- Safe to run more than once.
--
-- An online order is invoiced when it is packed: channel 'online', status 'unpaid' (waiting for the
-- money), no cash shift. It becomes 'paid' when the courier hands over the cash (payment method
-- 'cod') or when the customer pays at the counter. POS invoices keep the shift they always had.
-- Reports only count 'paid', so an unpaid invoice is not revenue yet.

alter table public.invoices add column if not exists channel text not null default 'pos';

alter table public.invoices drop constraint if exists invoices_channel_check;
alter table public.invoices add constraint invoices_channel_check check (channel in ('pos', 'online'));

alter table public.invoices alter column shift_id drop not null;

alter table public.invoices drop constraint if exists invoices_pos_needs_shift;
alter table public.invoices add constraint invoices_pos_needs_shift check (channel = 'online' or shift_id is not null);

alter table public.invoices drop constraint if exists invoices_status_check;
alter table public.invoices add constraint invoices_status_check check (status in ('paid', 'unpaid', 'cancelled'));

alter table public.payments drop constraint if exists payments_method_check;
alter table public.payments add constraint payments_method_check check (method in ('cash', 'transfer', 'card', 'cod'));

-- Cancelling a paid or an unpaid invoice puts its stock back.
drop trigger if exists restock_on_cancel on public.invoices;
create trigger restock_on_cancel after update of status on public.invoices
  for each row when (old.status in ('paid', 'unpaid') and new.status = 'cancelled')
  execute function public.invoice_cancel_restock();

notify pgrst, 'reload schema';
