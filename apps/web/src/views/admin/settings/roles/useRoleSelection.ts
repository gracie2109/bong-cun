import { computed, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import type { Role } from "@/repositories/roles";

/**
 * Which role is open, kept in the URL (?role=cashier) so the matrix can link straight to it,
 * and whether a new role is being drafted instead.
 */
export const useRoleSelection = (roles: () => readonly Role[], canManage: () => boolean) => {
  const route = useRoute();
  const router = useRouter();

  const creating = ref(false);
  // Role whose name, description and grants seed a new role ("Nhân bản").
  const template = ref<Role | null>(null);

  const selectedId = computed(() => (typeof route.query.role === "string" ? route.query.role : null));
  const selected = computed(() => roles().find((role) => role.id === selectedId.value) ?? roles()[0] ?? null);
  const isSelected = (role: Role): boolean => !creating.value && selected.value?.id === role.id;

  const select = (id: string) => {
    creating.value = false;
    router.replace({ query: { ...route.query, role: id, new: undefined } });
  };

  const startNew = (from: Role | null) => {
    template.value = from;
    creating.value = true;
  };

  /** Leaves the URL's role when it was the one just deleted. */
  const clearIfSelected = (id: string) => {
    if (selected.value?.id === id) router.replace({ query: { ...route.query, role: undefined } });
  };

  watch(selectedId, (id) => {
    if (id) creating.value = false;
  });

  // The matrix screen's "Thêm vai trò" button links here with ?new=1.
  watch(
    () => route.query.new,
    (value) => {
      if (value && canManage()) startNew(null);
    },
    { immediate: true }
  );

  return { creating, template, selected, isSelected, select, startNew, clearIfSelected };
};
