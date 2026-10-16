import { computed, ref, type Ref } from "vue";
import type { Permission } from "@/repositories/permissions";
import type { Role } from "@/repositories/roles";
import { METHODS, methodsOf, type Method } from "../rbac";
import { groupGranted, grantsOf, sameMethods, type Grants } from "./roleGrants";

/** Editable permission grants of a role, compared against the saved role to count the changes. */
export const useRoleGrants = (
  savedRole: () => Role | null,
  permissions: () => readonly Permission[],
  isSuperAdmin: Ref<boolean>
) => {
  const grants = ref<Grants>({});

  const initialGrants = computed(() => grantsOf(savedRole(), permissions()));

  /** Permissions whose grants differ from the saved role. */
  const changedCount = computed(
    () =>
      permissions().filter(
        (permission) => !sameMethods(grants.value[permission.id], initialGrants.value[permission.id])
      ).length
  );

  const selectedCount = computed(() => groupGranted(grants.value, permissions(), isSuperAdmin.value));

  /** Replaces the edits with the grants of `role` (empty for none). */
  const load = (role: Role | null) => {
    grants.value = grantsOf(role, permissions());
  };

  const setCell = (permissionId: string, method: Method, on: boolean) => {
    const current = grants.value[permissionId] ?? [];
    const next = on ? [...new Set([...current, method])] : current.filter((item) => item !== method);
    grants.value = { ...grants.value, [permissionId]: METHODS.filter((item) => next.includes(item)) };
  };

  const setRow = (permission: Permission, on: boolean) => {
    grants.value = { ...grants.value, [permission.id]: on ? methodsOf(permission) : [] };
  };

  const setGroup = (items: readonly Permission[], on: boolean) => {
    for (const permission of items) setRow(permission, on);
  };

  return { grants, changedCount, selectedCount, load, setCell, setRow, setGroup };
};
