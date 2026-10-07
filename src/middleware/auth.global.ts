import { canAccess, canOpenAdminRoute } from "@/lib/access";
import { useAuthStore } from "@/stores";

/** Pages a signed-in user should not see, matched against `meta.titleKey`. */
const GUEST_ONLY_KEYS = ["login", "register"];

// UX gating only; Row Level Security in the database is the real enforcement.
export default defineNuxtRouteMiddleware(async (to) => {
  const auth = useAuthStore();
  // Wait for the stored session to be restored, otherwise a page refresh would
  // look signed-out for a moment and bounce the user to the home page.
  await auth.init();

  const allowed = canAccess(
    {
      requiresAuth: to.meta.requiresAuth,
      roles: to.meta.roles,
      staffOnly: to.meta.staffOnly,
      guestOnly: GUEST_ONLY_KEYS.includes(to.meta.titleKey as string),
    },
    { isAuthenticated: auth.isAuthenticated, role: auth.role }
  );
  if (!allowed) return navigateTo({ name: "home" });

  // Inside /admin each page needs VIEW on its permission; without it, fall back to the dashboard.
  // Grants load on every admin route, the dashboard included, because the sidebar menu reads them.
  if (to.meta.staffOnly) {
    await auth.loadAdminGrants();
    if (to.name !== "dashboard" && !canOpenAdminRoute(auth.adminGrants ?? {}, to.name as string)) {
      return navigateTo({ name: "dashboard" });
    }
  }
});
