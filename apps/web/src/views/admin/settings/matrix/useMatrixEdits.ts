import { computed, ref } from "vue";
import { useUpdateRole } from "@/queries/roles";
import type { Permission } from "@/repositories/permissions";
import type { Role } from "@/repositories/roles";
import { methodsOf, roleMethods, type Method } from "../rbac";

/** Quick edit of the role/permission grid: cells changed since the last save, and saving them. */
export const useMatrixEdits = (roles: () => readonly Role[], permissions: () => readonly Permission[]) => {
  const updateRole = useUpdateRole();

  const quickEdit = ref(false);
  const saving = ref(false);
  // role name -> permission id -> methods, only for cells changed since the last save.
  const edits = ref<Record<string, Record<string, Method[]>>>({});

  const editCount = computed(() =>
    Object.values(edits.value).reduce((sum, cells) => sum + Object.keys(cells).length, 0)
  );

  const cellMethods = (role: Role, permission: Permission): Method[] =>
    edits.value[role.name]?.[permission.id] ?? roleMethods(role, permission);

  const cellState = (role: Role, permission: Permission): boolean | "indeterminate" => {
    const count = cellMethods(role, permission).length;
    if (count === 0) return false;
    return count === methodsOf(permission).length ? true : "indeterminate";
  };

  /** Ticking a cell grants every method the permission offers; unticking removes them all. */
  const toggleCell = (role: Role, permission: Permission, on: boolean) => {
    const next = on ? methodsOf(permission) : [];
    const saved = roleMethods(role, permission);
    const cells = { ...(edits.value[role.name] ?? {}) };
    if (next.length === saved.length && next.every((method) => saved.includes(method))) delete cells[permission.id];
    else cells[permission.id] = next;
    edits.value = { ...edits.value, [role.name]: cells };
  };

  const saveMatrix = async () => {
    saving.value = true;
    try {
      for (const [roleName, cells] of Object.entries(edits.value)) {
        const role = roles().find((item) => item.name === roleName);
        if (!role || Object.keys(cells).length === 0) continue;
        const permissionsInput = permissions()
          .map((permission) => ({ id: permission.id, method: cells[permission.id] ?? roleMethods(role, permission) }))
          .filter((grant) => grant.method.length > 0);
        await updateRole.mutateAsync({
          id: role.id,
          input: { name: role.name, description: role.description, permissions: permissionsInput },
        });
        const { [roleName]: _done, ...rest } = edits.value;
        edits.value = rest;
      }
      quickEdit.value = false;
    } catch {
      // the mutation already showed the failure toast; unsaved roles keep their edits
    } finally {
      saving.value = false;
    }
  };

  return { quickEdit, saving, editCount, cellMethods, cellState, toggleCell, saveMatrix };
};
