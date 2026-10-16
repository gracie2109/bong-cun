import { ref, type Ref, type ShallowRef } from "vue";
import { canUse, isAdminRole, isStaffRole, SUPER_ADMIN_ROLE, type AdminGrants } from "@bongcun/core/auth";
import type { AuthSession, DbClient } from "@bongcun/supabase/shared";
import { listMyPermissions } from "@bongcun/supabase/users";

type Context = {
  supabase: DbClient;
  session: ShallowRef<AuthSession | null>;
  role: Ref<string | null>;
  /** Resolves once the role for the current token has been loaded. */
  whenSessionApplied: () => Promise<void>;
};

/** What the signed-in staff member may do in /admin, from my_permissions(). Loaded on
 * demand by the route middleware and reloaded when the access token changes. */
export function createAdminGrants({ supabase, session, role, whenSessionApplied }: Context) {
  const adminGrants = ref<AdminGrants | null>(null);
  let grantsToken: string | null | undefined;
  let grantsPromise: Promise<void> = Promise.resolve();

  function loadAdminGrants() {
    const token = session.value?.access_token ?? null;
    if (token === grantsToken) return grantsPromise;
    grantsToken = token;
    grantsPromise = (async () => {
      await whenSessionApplied(); // the role for this token must be loaded first
      if (role.value === SUPER_ADMIN_ROLE) {
        adminGrants.value = "all";
        return;
      }
      if (!isStaffRole(role.value)) {
        adminGrants.value = {};
        return;
      }
      try {
        const grants = await listMyPermissions(supabase);
        // An admin account with no role at any branch yet keeps the full menu it had before
        // branch roles existed (is_admin() still lets it through RLS).
        const legacyAdmin = isAdminRole(role.value) && Object.keys(grants).length === 0;
        if (grantsToken === token) adminGrants.value = legacyAdmin ? "all" : grants;
      } catch (error) {
        console.error("Failed to load permissions", error);
        if (grantsToken === token) adminGrants.value = {};
        grantsToken = undefined; // retry on the next navigation
      }
    })();
    return grantsPromise;
  }

  const can = (permission: string, method = "VIEW"): boolean =>
    !!adminGrants.value && canUse(adminGrants.value, permission, method);

  return { adminGrants, loadAdminGrants, can };
}
