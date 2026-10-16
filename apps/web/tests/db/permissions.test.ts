// Permission tests: the grants in the database, the copy the app uses to hide menus, and row
// security per role and branch must say the same thing.
import { randomUUID } from "node:crypto";
import { describe, expect, it } from "vitest";
import { ADMIN_ROUTE_PERMISSIONS, canUse, type AdminGrants } from "@bongcun/core/auth";
import { createBranch, createProduct, createStaff, createUser } from "./fixtures";
import { DATABASE_URL, inTransaction, type Tx } from "./harness";

const METHODS = ["VIEW", "CREATE", "UPDATE", "DELETE", "IMPORT", "EXPORT", "SETTING"] as const;
const ROLES = ["admin", "cashier", "vet", "inventory"] as const;

const hasPermission = async (tx: Tx, permission: string, method: string, branch: string | null): Promise<boolean> =>
  (await tx.q<{ ok: boolean }>("select public.has_permission($1, $2, $3) as ok", [permission, method, branch]))[0]!.ok;

describe.skipIf(!DATABASE_URL)("permission codes", () => {
  it("every admin page points at a permission that exists", () =>
    inTransaction(async (tx) => {
      const codes = new Set((await tx.q<{ name: string }>("select name from public.permissions")).map((row) => row.name));
      const missing = Object.entries(ADMIN_ROUTE_PERMISSIONS).filter(([, code]) => !codes.has(code));
      expect(missing).toEqual([]);
    }));

  it("canUse (menus) agrees with has_permission (database) for every role, permission and method", () =>
    inTransaction(async (tx) => {
      const branch = await createBranch(tx);
      const codes = (await tx.q<{ name: string }>("select name from public.permissions")).map((row) => row.name);
      const grantRows = await tx.q<{ role: string; permission: string; methods: string[] }>(
        "select role, permission, methods from public.role_permissions"
      );
      const disagreements: string[] = [];
      for (const role of ROLES) {
        await tx.admin();
        const user = await createStaff(tx, branch, role);
        const grants: AdminGrants = Object.fromEntries(
          grantRows.filter((row) => row.role === role).map((row) => [row.permission, row.methods])
        );
        await tx.as(user);
        for (const code of codes) {
          for (const method of METHODS) {
            const inDb = await hasPermission(tx, code, method, branch);
            if (inDb !== canUse(grants, code, method)) disagreements.push(`${role} ${code} ${method}: db=${inDb}`);
          }
        }
      }
      expect(disagreements).toEqual([]);
    }));
});

describe.skipIf(!DATABASE_URL)("has_permission per role and branch", () => {
  it("grants follow the role, and stop at the branch", () =>
    inTransaction(async (tx) => {
      const [a, b] = [await createBranch(tx), await createBranch(tx)];
      const cashier = await createStaff(tx, a, "cashier");
      const vet = await createStaff(tx, a, "vet");
      const manager = await createStaff(tx, a, "admin");
      const customer = await createUser(tx);
      const superAdmin = await createUser(tx, "superAdmin");

      await tx.as(cashier);
      expect(await hasPermission(tx, "pos", "CREATE", a)).toBe(true);
      expect(await hasPermission(tx, "pos", "DELETE", a)).toBe(false);
      expect(await hasPermission(tx, "pos", "CREATE", b)).toBe(false);

      await tx.as(vet);
      expect(await hasPermission(tx, "medical", "UPDATE", a)).toBe(true);
      expect(await hasPermission(tx, "pos", "VIEW", a)).toBe(false);

      await tx.as(manager);
      expect(await hasPermission(tx, "pos", "DELETE", a)).toBe(true);
      expect(await hasPermission(tx, "pos", "DELETE", b)).toBe(false);

      await tx.as(customer);
      expect(await hasPermission(tx, "pos", "VIEW", null)).toBe(false);

      await tx.as(superAdmin);
      expect(await hasPermission(tx, "pos", "DELETE", b)).toBe(true);
    }));
});

describe.skipIf(!DATABASE_URL)("row security on invoices", () => {
  it("staff read only their own branch, and a vet or customer read none", () =>
    inTransaction(async (tx) => {
      const [a, b] = [await createBranch(tx), await createBranch(tx)];
      const product = await createProduct(tx, a, 10000, 50);
      await tx.q(
        "insert into public.stock_lots (branch_id, product_id, lot_no, qty_on_hand, unit_cost) values ($1, $2, 'L1', 50, 1000)",
        [b, product]
      );
      const cashierA = await createStaff(tx, a, "cashier", true);
      const cashierB = await createStaff(tx, b, "cashier", true);
      const vetA = await createStaff(tx, a, "vet");
      const customer = await createUser(tx);

      const sell = async (user: string, branch: string) => {
        await tx.as(user);
        await tx.q("select public.create_invoice($1::jsonb)", [
          JSON.stringify({
            branch_id: branch,
            client_ref: randomUUID(),
            lines: [{ type: "product", id: product, qty: 1 }],
            payments: [{ method: "cash", amount: 10000 }],
          }),
        ]);
      };
      await sell(cashierA, a);
      await sell(cashierB, b);

      const branchesSeenBy = async (user: string) => {
        await tx.as(user);
        return (await tx.q<{ branch_id: string }>("select branch_id from public.invoices")).map((row) => row.branch_id);
      };
      expect(await branchesSeenBy(cashierA)).toEqual([a]);
      expect(await branchesSeenBy(cashierB)).toEqual([b]);
      expect(await branchesSeenBy(vetA)).toEqual([]);
      expect(await branchesSeenBy(customer)).toEqual([]);
    }));

  it("a cashier cannot sell at, or open a shift in, another branch", () =>
    inTransaction(async (tx) => {
      const [a, b] = [await createBranch(tx), await createBranch(tx)];
      const product = await createProduct(tx, b, 10000, 5);
      const cashierA = await createStaff(tx, a, "cashier", true);
      await tx.as(cashierA);
      const sale = await tx.fails("select public.create_invoice($1::jsonb)", [
        JSON.stringify({
          branch_id: b,
          lines: [{ type: "product", id: product, qty: 1 }],
          payments: [{ method: "cash", amount: 10000 }],
        }),
      ]);
      expect(sale.code).toBe("42501");
      expect((await tx.fails("select public.open_cash_shift($1, 0)", [b])).code).toBe("42501");
    }));
});
