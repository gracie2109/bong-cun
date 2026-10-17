import type { Session } from "./db";

// An admin at a new branch, a customer with one pet and one medical service.
export const setUpVisit = async (db: Session) => {
  const branch = await db.scalar<string>("select tests.create_branch('CT7')");
  const admin = await db.scalar<string>("select tests.create_staff('contract-medical@test.local', $1, 'cashier')", [branch]);
  await db.rows("update public.users set role = 'admin' where id = $1", [admin]);
  const customer = await db.scalar<string>("select tests.create_patient('0900000701', 'Contract Vet Pet')");
  const pet = await db.scalar<string>("select tests.pet_of($1)", [customer]);
  const service = await db.scalar<string>(
    "insert into public.pet_services (name, type, general_price, duration_minutes, category) values ('Contract exam', 'all', 120000, 30, 'medical') returning id"
  );
  await db.signIn(admin);
  return { branch, customer, pet, service };
};
