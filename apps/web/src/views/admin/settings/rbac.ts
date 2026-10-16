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

/** Lowercase without Vietnamese accents, so "quyen" finds "Quyền". */
export const fold = (text: string): string =>
  text.normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/đ/gi, "d").toLowerCase().trim();

// Modules are free text, so the icon is picked from words in the module name.
const MODULE_ICON_RULES: [RegExp, string][] = [
  [/khach|customer/, "lucide:users"],
  [/thu cung|pet|ho so/, "lucide:paw-print"],
  [/dich vu|gia|spa|service|price/, "lucide:scissors"],
  [/lich|booking|appointment|dat cho/, "lucide:calendar-days"],
  [/ban hang|hoa don|pos|thu ngan|invoice|sale/, "lucide:receipt"],
  [/kho|inventory|stock|san pham|product/, "lucide:package"],
  [/bao cao|report|doanh thu/, "lucide:chart-column"],
  [/he thong|cai dat|setting|system|phan quyen|tai khoan/, "lucide:settings"],
];

export const moduleIcon = (module: string | null): string => {
  const key = fold(module ?? "");
  return MODULE_ICON_RULES.find(([pattern]) => pattern.test(key))?.[1] ?? "lucide:folder-key";
};

export const SUPER_ADMIN_ROLE = "superAdmin";
export const CUSTOMER_ROLE = "customer";

/** The methods a role holds on a permission; superAdmin passes every has_permission() check. */
export const roleMethods = (
  role: { name: string; permissions: readonly RolePermissionGrant[] },
  permission: Pick<Permission, "id" | "methods">
): Method[] => (role.name === SUPER_ADMIN_ROLE ? methodsOf(permission) : grantedMethods(role.permissions, permission));

/** How many permissions a role holds at least one method on. */
export const grantedCount = (
  role: { name: string; permissions: readonly RolePermissionGrant[] },
  permissions: readonly Permission[]
): number => permissions.filter((permission) => roleMethods(role, permission).length > 0).length;
