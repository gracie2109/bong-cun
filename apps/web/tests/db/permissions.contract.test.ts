import { ADMIN_ROUTE_PERMISSIONS } from "@bongcun/core/auth";
import { describe, expect, it } from "vitest";
import { inRolledBackTransaction } from "./db";

// The admin menu hides pages by these codes (VIEW), while the database decides what a call may do.
// A code missing from the permissions table would hide a page from everyone but admins.
describe("Admin route permissions exist in the database", () => {
  it("every code in ADMIN_ROUTE_PERMISSIONS is a permission that has the VIEW method", async () => {
    await inRolledBackTransaction(async (db) => {
      const rows = await db.rows<{ name: string; methods: string[] }>("select name, methods from public.permissions");
      const methodsByCode = new Map(rows.map((row) => [row.name, row.methods]));
      const problems = [...new Set(Object.values(ADMIN_ROUTE_PERMISSIONS))]
        .filter((code) => !methodsByCode.get(code)?.some((method) => method === "VIEW" || method === "ALL"))
        .sort();
      expect(problems, "permission codes with no VIEW method in the permissions table").toEqual([]);
    });
  });
});
