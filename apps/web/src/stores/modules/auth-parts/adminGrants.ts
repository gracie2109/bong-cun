import { ref, type Ref, type ShallowRef } from "vue";
import {
  canUse,
  canUseAt,
  isAdminRole,
  isStaffRole,
  SUPER_ADMIN_ROLE,
  type AdminGrants,
  type BranchGrants,
} from "@bongcun/core/auth";
import type { AuthSession, DbClient } from "@bongcun/supabase/shared";
import { listMyGrants } from "@bongcun/supabase/users";

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
  // The same grants kept per branch, for screens that show one branch at a time.
  const branchGrants = ref<BranchGrants>({});
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
        branchGrants.value = {};
        return;
      }
      if (!isStaffRole(role.value)) {
        adminGrants.value = {};
        branchGrants.value = {};
        return;
      }
      try {
        const { merged: grants, byBranch } = await listMyGrants(supabase);
        // An admin account with no role at any branch yet keeps the full menu it had before
        // branch roles existed (is_admin() still lets it through RLS).
        const legacyAdmin = isAdminRole(role.value) && Object.keys(grants).length === 0;
        if (grantsToken === token) {
          adminGrants.value = legacyAdmin ? "all" : grants;
          branchGrants.value = byBranch;
        }
      } catch (error) {
        console.error("Failed to load permissions", error);
        if (grantsToken === token) {
          adminGrants.value = {};
          branchGrants.value = {};
        }
        grantsToken = undefined; // retry on the next navigation
      }
    })();
    return grantsPromise;
  }

  const can = (permission: string, method = "VIEW"): boolean =>
    !!adminGrants.value && canUse(adminGrants.value, permission, method);

  /** Whether the account holds the permission at this branch (not at "any branch" like `can`). */
  const canAt = (permission: string, branchId: string | null | undefined, method = "VIEW"): boolean =>
    !!adminGrants.value && canUseAt(adminGrants.value, branchGrants.value, permission, branchId, method);

  return { adminGrants, branchGrants, loadAdminGrants, can, canAt };
}
