// Shared helpers for the role and permission screens.
import type { Permission } from "@/repositories/permissions";
import type { RolePermissionGrant } from "@/repositories/roles";

/** The methods a role can be granted, in the column order of every grid. */
export const METHODS = ["VIEW", "CREATE", "UPDATE", "DELETE", "IMPORT", "EXPORT", "SETTING"] as const;
export type Method = (typeof METHODS)[number];

/** Stored on a permission or grant, it means every method. The editors expand it. */
export const ALL_METHOD = "ALL";

export const METHOD_ICONS: Record<Method, string> = {
  VIEW: "lucide:eye",
  CREATE: "lucide:plus",
  UPDATE: "lucide:pencil",
  DELETE: "lucide:trash-2",
  IMPORT: "lucide:upload",
  EXPORT: "lucide:download",
  SETTING: "lucide:sliders-horizontal",
};

/** The methods a permission offers, with ALL expanded to every method. */
export const methodsOf = (permission: Pick<Permission, "methods">): Method[] =>
  permission.methods.includes(ALL_METHOD)
    ? [...METHODS]
    : METHODS.filter((method) => permission.methods.includes(method));

/** The methods a role grants on a permission, limited to what the permission offers. */
export const grantedMethods = (
  grants: readonly RolePermissionGrant[],
  permission: Pick<Permission, "id" | "methods">
): Method[] => {
  const grant = grants.find((item) => item.id === permission.id);
  if (!grant) return [];
  const offered = methodsOf(permission);
  return grant.method.includes(ALL_METHOD) ? offered : offered.filter((method) => grant.method.includes(method));
};

export type PermissionGroup = { module: string | null; items: Permission[] };

/** Permissions grouped by module, keeping the list order; ungrouped ones go last. */
export const groupByModule = (permissions: readonly Permission[]): PermissionGroup[] => {
  const groups = new Map<string | null, Permission[]>();
  for (const permission of permissions) {
    const key = permission.module?.trim() || null;
    groups.set(key, [...(groups.get(key) ?? []), permission]);
  }
  const named = [...groups.entries()].filter(([module]) => module !== null);
  const ungrouped = groups.get(null);
  return [
    ...named.map(([module, items]) => ({ module, items })),
    ...(ungrouped ? [{ module: null, items: ungrouped }] : []),
  ];
};

/** Permission codes are used in RLS and code, so they stay ASCII. */
export const PERMISSION_CODE_PATTERN = /^[a-zA-Z][a-zA-Z0-9_.]*$/;
export const ROLE_CODE_PATTERN = /^[a-zA-Z][a-zA-Z0-9_]*$/;
