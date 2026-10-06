// Pure access-control helpers: no Vue, no router, no Pinia. The Vue Router guard
// calls canAccess() today; a Nuxt route middleware can call the same function.
// This is UX gating only. Real enforcement is Row Level Security in the database.

export const ADMIN_ROLES = ["admin", "superAdmin"] as const;

export type AccessState = {
  isAuthenticated: boolean;
  role: string | null;
};

export type AccessMeta = {
  requiresAuth?: boolean;
  /** Allowed roles. When set, the user must hold one of them. */
  roles?: readonly string[];
  /** Pages such as login/register that a signed-in user should not see. */
  guestOnly?: boolean;
};

export const isAdminRole = (role: string | null | undefined): boolean =>
  !!role && (ADMIN_ROLES as readonly string[]).includes(role);

export const canAccess = (meta: AccessMeta, state: AccessState): boolean => {
  if (meta.guestOnly && state.isAuthenticated) return false;
  if (meta.requiresAuth && !state.isAuthenticated) return false;
  if (meta.roles && (!state.role || !meta.roles.includes(state.role))) return false;
  return true;
};
