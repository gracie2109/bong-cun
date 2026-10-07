import { computed } from "vue";
import { SUPER_ADMIN_ROLE } from "@/lib/access";
import { useAuthStore } from "@/stores";

// What the signed-in staff member may do with one permission code (users, pets, ...), for
// hiding buttons the database would refuse anyway. RLS still enforces every write.
export function usePermission(permission: string) {
  const auth = useAuthStore();
  return {
    canCreate: computed(() => auth.can(permission, "CREATE")),
    canUpdate: computed(() => auth.can(permission, "UPDATE")),
    canDelete: computed(() => auth.can(permission, "DELETE")),
  };
}

// Roles, permissions and staff assignments are written by a superAdmin only (RLS on roles,
// role_permissions and staff_branches); everyone else sees those screens read-only.
export function useCanManageRbac() {
  const auth = useAuthStore();
  return computed(() => auth.role === SUPER_ADMIN_ROLE);
}
