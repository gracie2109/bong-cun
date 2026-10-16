import type { Permission } from "@/repositories/permissions";
import type { Role } from "@/repositories/roles";
import { grantedMethods, methodsOf, type Method } from "../rbac";

/** Granted methods per permission id; permissions with none are left out. */
export type Grants = Record<string, Method[]>;
export type CheckState = boolean | "indeterminate";

export const grantsOf = (role: Role | null, permissions: readonly Permission[]): Grants =>
  Object.fromEntries(
    permissions
      .map((permission) => [permission.id, role ? grantedMethods(role.permissions, permission) : []] as const)
      .filter(([, methods]) => methods.length > 0)
  );

export const sameMethods = (a: readonly Method[] = [], b: readonly Method[] = []): boolean =>
  a.length === b.length && a.every((method) => b.includes(method));

/** A superAdmin always holds everything, whatever the grants say. */
export const rowState = (grants: Grants, permission: Permission, isSuperAdmin: boolean): CheckState => {
  if (isSuperAdmin) return true;
  const count = grants[permission.id]?.length ?? 0;
  if (count === 0) return false;
  return count === methodsOf(permission).length ? true : "indeterminate";
};

export const groupGranted = (grants: Grants, items: readonly Permission[], isSuperAdmin: boolean): number =>
  items.filter((item) => rowState(grants, item, isSuperAdmin) !== false).length;

export const groupState = (grants: Grants, items: readonly Permission[], isSuperAdmin: boolean): CheckState => {
  const states = items.map((item) => rowState(grants, item, isSuperAdmin));
  if (states.every((state) => state === true)) return true;
  return states.every((state) => state === false) ? false : "indeterminate";
};
