import { canUse, type AdminGrants } from "@bongcun/core/auth";
import { describe, expect, it } from "vitest";
import { inRolledBackTransaction, type Session } from "./db";

// The admin menu decides what to show with canUse(); the database decides what a call may do with
// has_permission() and row security. These tests make the two say the same thing, per role and branch.
const METHODS = ["VIEW", "CREATE", "UPDATE", "DELETE", "IMPORT", "EXPORT", "SETTING"] as const;
const ROLES = ["admin", "cashier", "vet", "inventory"] as const;

const allowed = (db: Session, permission: string, method: string, branch: string | null) =>
  db.scalar<boolean>("select public.has_permission($1, $2, $3)", [permission, method, branch]);

// Back to the owner first: as another signed-in user the claims lookup could not see this user's row.
const signInAs = async (db: Session, user: string) => {
  await db.signOut();
  await db.signIn(user);
};

const branchCode = (n: number) => `PB${n}`;
const makeBranches = async (db: Session) => ({
  a: await db.scalar<string>("select tests.create_branch($1)", [branchCode(1)]),
  b: await db.scalar<string>("select tests.create_branch($1)", [branchCode(2)]),
});
const staff = (db: Session, email: string, branch: string, role: string, withShift = false) =>
  db.scalar<string>(`select tests.${withShift ? "create_cashier" : "create_staff"}($1, $2, $3)`, [email, branch, role]);

describe("canUse (menus) agrees with has_permission (database)", () => {
  it("for every role, permission and method", async () => {
    await inRolledBackTransaction(async (db) => {
      const { a } = await makeBranches(db);
      const codes = (await db.rows<{ name: string }>("select name from public.permissions")).map((row) => row.name);
      const grantRows = await db.rows<{ role: string; permission: string; methods: string[] }>(
        "select role, permission, methods from public.role_permissions"
      );
      const disagreements: string[] = [];
      for (const role of ROLES) {
        const user = await staff(db, `parity-${role}@test.local`, a, role);
        const grants: AdminGrants = Object.fromEntries(
          grantRows.filter((row) => row.role === role).map((row) => [row.permission, row.methods])
        );
        await signInAs(db, user);
        for (const code of codes) {
          for (const method of METHODS) {
            const inDb = await allowed(db, code, method, a);
            if (inDb !== canUse(grants, code, method)) disagreements.push(`${role} ${code} ${method}: database says ${inDb}`);
          }
        }
        await db.signOut();
      }
      expect(disagreements).toEqual([]);
    });
  });
});

describe("has_permission per role and branch", () => {
  it("follows the role and stops at the branch", async () => {
    await inRolledBackTransaction(async (db) => {
      const { a, b } = await makeBranches(db);
      const cashier = await staff(db, "scope-cashier@test.local", a, "cashier");
      const vet = await staff(db, "scope-vet@test.local", a, "vet");
      const manager = await staff(db, "scope-admin@test.local", a, "admin");
      const customer = await db.scalar<string>("select tests.create_user('scope-buyer@test.local')");
      const superAdmin = await db.scalar<string>("select tests.create_user('scope-super@test.local', 'superAdmin')");

      await signInAs(db, cashier);
      expect(await allowed(db, "pos", "CREATE", a)).toBe(true);
      expect(await allowed(db, "pos", "DELETE", a)).toBe(false);
      expect(await allowed(db, "pos", "CREATE", b)).toBe(false);
      await signInAs(db, vet);
      expect(await allowed(db, "medical", "UPDATE", a)).toBe(true);
      expect(await allowed(db, "pos", "VIEW", a)).toBe(false);
      await signInAs(db, manager);
      expect(await allowed(db, "pos", "DELETE", a)).toBe(true);
      expect(await allowed(db, "pos", "DELETE", b)).toBe(false);
      await signInAs(db, customer);
      expect(await allowed(db, "pos", "VIEW", null)).toBe(false);
      await signInAs(db, superAdmin);
      expect(await allowed(db, "pos", "DELETE", b)).toBe(true);
    });
  });
});

describe("row security on invoices", () => {
  it("lets staff read only their own branch, and a vet or customer none", async () => {
    await inRolledBackTransaction(async (db) => {
      const { a, b } = await makeBranches(db);
      const product = await db.scalar<string>("select tests.create_product('Parity pate', 10000)");
      await db.scalar("select tests.add_lot($1, $2, 20, null, 'P-A')", [a, product]);
      await db.scalar("select tests.add_lot($1, $2, 20, null, 'P-B')", [b, product]);
      const cashierA = await staff(db, "rls-cashier-a@test.local", a, "cashier", true);
      const cashierB = await staff(db, "rls-cashier-b@test.local", b, "cashier", true);
      const vetA = await staff(db, "rls-vet-a@test.local", a, "vet");
      const customer = await db.scalar<string>("select tests.create_user('rls-buyer@test.local')");

      const sell = async (user: string, branch: string) => {
        await signInAs(db, user);
        await db.rpc("create_invoice", {
          branch_id: branch,
          lines: [{ type: "product", id: product, qty: 1 }],
          payments: [{ method: "cash", amount: 10000 }],
        });
      };
      await sell(cashierA, a);
      await sell(cashierB, b);

      const branchesSeenBy = async (user: string) => {
        await signInAs(db, user);
        return (await db.rows<{ branch_id: string }>("select branch_id from public.invoices")).map((row) => row.branch_id);
      };
      expect(await branchesSeenBy(cashierA)).toEqual([a]);
      expect(await branchesSeenBy(cashierB)).toEqual([b]);
      expect(await branchesSeenBy(vetA)).toEqual([]);
      expect(await branchesSeenBy(customer)).toEqual([]);
    });
  });

  it("stops a cashier selling at, or opening a shift in, another branch", async () => {
    await inRolledBackTransaction(async (db) => {
      const { a, b } = await makeBranches(db);
      const product = await db.scalar<string>("select tests.create_product('Parity collar', 10000)");
      await db.scalar("select tests.add_lot($1, $2, 5, null, 'P-B')", [b, product]);
      const cashierA = await staff(db, "cross-cashier@test.local", a, "cashier", true);
      await signInAs(db, cashierA);
      await expect(
        db.rpc("create_invoice", {
          branch_id: b,
          lines: [{ type: "product", id: product, qty: 1 }],
          payments: [{ method: "cash", amount: 10000 }],
        })
      ).rejects.toMatchObject({ code: "42501" });
    });
  });

  it("stops a cashier opening a shift in another branch", async () => {
    await inRolledBackTransaction(async (db) => {
      const { a, b } = await makeBranches(db);
      const cashierA = await staff(db, "cross-shift@test.local", a, "cashier");
      await signInAs(db, cashierA);
      await expect(db.scalar("select public.open_cash_shift($1, 0)", [b])).rejects.toMatchObject({ code: "42501" });
    });
  });
});
