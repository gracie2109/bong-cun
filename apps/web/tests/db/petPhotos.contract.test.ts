import { describe, expect, it } from "vitest";
import { inRolledBackTransaction } from "./db";

// set_pet_photo is allowed for whoever can update (or create) pets: the same answer as has_permission.
const ROLES = ["admin", "cashier", "vet", "inventory"] as const;

describe("set_pet_photo agrees with has_permission on pets", () => {
  it("lets a role through exactly when it may update or create pets", async () => {
    await inRolledBackTransaction(async (db) => {
      const branch = await db.scalar<string>("select tests.create_branch('PP')");
      const owner = await db.scalar<string>("select tests.create_patient('0900000009', 'Bi')");
      const pet = await db.scalar<string>("select tests.pet_of($1)", [owner]);
      const disagreements: string[] = [];
      for (const role of ROLES) {
        const user = await db.scalar<string>("select tests.create_staff($1, $2, $3)", [`photo-${role}@test.local`, branch, role]);
        await db.signOut();
        await db.signIn(user);
        const mayEdit = await db.scalar<boolean>(
          "select public.has_permission('pets', 'UPDATE') or public.has_permission('pets', 'CREATE')"
        );
        await db.rows("savepoint photo");
        const code = await db
          .scalar("select public.set_pet_photo($1, null, null)", [pet])
          .then(() => "ok")
          .catch((error: { code?: string }) => error.code ?? "error");
        await db.rows("rollback to savepoint photo");
        if ((code === "ok") !== mayEdit) disagreements.push(`${role}: has_permission ${mayEdit}, set_pet_photo ${code}`);
      }
      expect(disagreements).toEqual([]);
    });
  });
});
