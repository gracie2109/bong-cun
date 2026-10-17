import type { Session } from "./db";

// Fixtures shared by the boarding contract tests.
const DAY = "(date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') + interval '%s') at time zone 'Asia/Ho_Chi_Minh'";
export const at = (interval: string) => DAY.replace("%s", interval);

// An admin at a new branch, a customer with one pet, and one ready kennel of a priced type.
export const setUpStay = async (db: Session) => {
  const branch = await db.scalar<string>("select tests.create_branch('CT6')");
  const admin = await db.scalar<string>("select tests.create_staff('contract-boarding@test.local', $1, 'cashier')", [branch]);
  await db.rows("update public.users set role = 'admin' where id = $1", [admin]);
  const customer = await db.scalar<string>("select tests.create_patient('0900000601', 'Contract Hotel Pet')");
  const pet = await db.scalar<string>("select tests.pet_of($1)", [customer]);
  const type = await db.scalar<string>(
    "insert into public.kennel_types (name, species_ids, purpose, max_pets) values ('Contract room', '{}', 'boarding', 1) returning id"
  );
  await db.rows("insert into public.kennel_type_prices (kennel_type_id, night_price) values ($1, 100000)", [type]);
  await db.rows("insert into public.kennels (branch_id, kennel_type_id, code) values ($1, $2, 'C1')", [branch, type]);
  const arrive = new Date(await db.scalar<string>(`select ${at("1 day 9 hours")}`)).toISOString();
  const leave = new Date(await db.scalar<string>(`select ${at("4 days 9 hours")}`)).toISOString();
  await db.signIn(admin);
  return { branch, customer, pet, type, arrive, leave };
};

export const payloadOf = (s: Awaited<ReturnType<typeof setUpStay>>) => ({
  branch_id: s.branch,
  customer_id: s.customer,
  planned_in_at: s.arrive,
  planned_out_at: s.leave,
  pets: [{ pet_id: s.pet, kennel_type_id: s.type }],
});
