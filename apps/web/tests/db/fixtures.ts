// Small builders for the rows the tests need. Run as the superuser, inside a rolled-back transaction.
import type { Tx } from "./harness";

let counter = 0;
const next = () => `${Date.now().toString(36)}${(counter++).toString(36)}`;

export const createBranch = async (tx: Tx): Promise<string> =>
  (await tx.q<{ id: string }>("insert into public.branches (code, name) values ($1, $1) returning id", [`T${Math.random().toString(36).slice(2, 8).toUpperCase().padEnd(6, "0")}`]))[0]!.id;

/** An auth user; `accountType` is users.role (customer, cashier, admin...). */
export const createUser = async (tx: Tx, accountType = "customer"): Promise<string> => {
  const email = `${next()}@test.local`;
  const [row] = await tx.q<{ id: string }>(
    `insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
     values (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', $1,
             jsonb_build_object('full_name', split_part($1, '@', 1)), now(), now()) returning id`,
    [email]
  );
  await tx.q("update public.users set role = $2 where id = $1", [row!.id, accountType]);
  return row!.id;
};

/** Staff who hold `role` at the branch (account type cashier), optionally with an open cash shift there. */
export const createStaff = async (tx: Tx, branchId: string, role: string, withShift = false): Promise<string> => {
  const user = await createUser(tx, "cashier");
  await tx.q("insert into public.staff_branches (user_id, branch_id, role) values ($1, $2, $3)", [user, branchId, role]);
  if (withShift) {
    await tx.q(
      "insert into public.cash_shifts (code, branch_id, opened_by, opening_cash) values ($1, $2, $3, 100000)",
      [`CA-${next()}`, branchId, user]
    );
  }
  return user;
};

/** A stock-tracked product with `qty` on hand at the branch. */
export const createProduct = async (tx: Tx, branchId: string, price: number, qty: number): Promise<string> => {
  const name = `Item ${next()}`;
  const [product] = await tx.q<{ id: string }>(
    `with g as (insert into public.product_groups (name) values ($1) returning id)
     insert into public.products (name, price, group_id, track_stock) select $1, $2, g.id, true from g returning id`,
    [name, price]
  );
  await tx.q(
    `insert into public.stock_lots (branch_id, product_id, lot_no, qty_on_hand, unit_cost) values ($1, $2, 'L1', $3, 1000)`,
    [branchId, product!.id, qty]
  );
  return product!.id;
};
