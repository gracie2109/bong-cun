// Pure access-control helpers: no Vue, no router, no Pinia. The Vue Router guard
// calls canAccess() today; a Nuxt route middleware can call the same function.
// This is UX gating only. Real enforcement is Row Level Security in the database.

export const ADMIN_ROLES = ["admin", "superAdmin"] as const;
export const CUSTOMER_ROLE = "customer";
export const SUPER_ADMIN_ROLE = "superAdmin";

export type AccessState = {
  isAuthenticated: boolean;
  role: string | null;
};

export type AccessMeta = {
  requiresAuth?: boolean;
  /** Allowed roles. When set, the user must hold one of them. */
  roles?: readonly string[];
  /** Pages for staff accounts: any account type other than customer. */
  staffOnly?: boolean;
  /** Pages such as login/register that a signed-in user should not see. */
  guestOnly?: boolean;
};

export const isAdminRole = (role: string | null | undefined): boolean =>
  !!role && (ADMIN_ROLES as readonly string[]).includes(role);

/** Any account type other than customer (admin, cashier, groomer...) is a staff account. */
export const isStaffRole = (role: string | null | undefined): boolean => !!role && role !== CUSTOMER_ROLE;

export const canAccess = (meta: AccessMeta, state: AccessState): boolean => {
  if (meta.guestOnly && state.isAuthenticated) return false;
  if (meta.requiresAuth && !state.isAuthenticated) return false;
  if (meta.roles && (!state.role || !meta.roles.includes(state.role))) return false;
  if (meta.staffOnly && !isStaffRole(state.role)) return false;
  return true;
};

/** Permission code -> methods the user holds at any branch. "all" for admin account types. */
export type AdminGrants = Record<string, readonly string[]> | "all";

export const canUse = (grants: AdminGrants, permission: string, method = "VIEW"): boolean =>
  grants === "all" || (grants[permission] ?? []).some((item) => item === method || item === "ALL");

// The permission code whose VIEW opens each admin page. Pages missing here (the
// dashboard) are open to every staff account.
export const ADMIN_ROUTE_PERMISSIONS: Record<string, string> = {
  users: "users",
  usersGroup: "users",
  pets: "pets",
  petDetail: "pets",
  petSpecies: "petServices",
  petService: "petServices",
  petPrices: "petServices",
  petServiceCombo: "petServices",
  listOrderSchedule: "schedule",
  detailOrderScheduleDetail: "schedule",
  settings: "settings",
  permissions: "settings",
  permissionMatrix: "settings",
};

export const canOpenAdminRoute = (grants: AdminGrants, routeName: string | null | undefined): boolean => {
  const permission = routeName ? ADMIN_ROUTE_PERMISSIONS[routeName] : undefined;
  return !permission || canUse(grants, permission);
};
