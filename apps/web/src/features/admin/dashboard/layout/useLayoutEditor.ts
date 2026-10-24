import { computed, ref, watch, type Ref } from "vue";
import { toast } from "vue-sonner";
import { toAppError } from "@bongcun/supabase/shared";
import type { SavedItem } from "@bongcun/core/dashboard";
import i18n from "@/i18n";
import { sameLayout } from "./layoutCodec";
import { useLayoutMutations } from "./useLayoutMutations";

type SavedLayout = {
  items: Ref<SavedItem[]>;
  version: Ref<number>;
  refetch: () => Promise<unknown>;
};

/**
 * Edit mode of one dashboard: a draft copy of the layout that only reaches the database on Save.
 * Saving sends the version it was based on; if the layout changed elsewhere meanwhile, `conflict` is set.
 */
export const useLayoutEditor = (dashboardKey: Ref<string | null>, saved: SavedLayout) => {
  const t = i18n.global.t;
  const { save, reset } = useLayoutMutations();
  const editing = ref(false);
  const draft = ref<SavedItem[]>([]);
  const conflict = ref(false);

  const items = computed(() => (editing.value ? draft.value : saved.items.value));
  const isDirty = computed(() => editing.value && !sameLayout(draft.value, saved.items.value));
  const saving = computed(() => save.isPending.value || reset.isPending.value);

  const start = () => {
    draft.value = saved.items.value.map((item) => ({ ...item }));
    editing.value = true;
  };
  const cancel = () => {
    editing.value = false;
    conflict.value = false;
  };
  /** Replaces the draft, e.g. after the grid moved something. */
  const update = (next: SavedItem[]) => {
    if (editing.value) draft.value = next;
  };

  const persist = async () => {
    if (!dashboardKey.value) return;
    try {
      await save.mutateAsync({ dashboardKey: dashboardKey.value, items: draft.value, expectedVersion: saved.version.value });
      toast.success(t("dashboard.layout.saved"));
      cancel();
    } catch (error) {
      if (toAppError(error)?.code === "layout_conflict") conflict.value = true;
      else toast.error(t("dashboard.layout.saveFailed"));
    }
  };

  /** "Overwrite with mine": read the current version, then save the draft on top of it. */
  const overwrite = async () => {
    conflict.value = false;
    await saved.refetch();
    await persist();
  };
  /** "Load the new one": drop the draft and show what is saved now. */
  const reload = async () => {
    await saved.refetch();
    cancel();
  };

  const restoreDefault = async () => {
    if (!dashboardKey.value) return;
    try {
      await reset.mutateAsync(dashboardKey.value);
      toast.success(t("dashboard.layout.resetDone"));
      cancel();
    } catch {
      toast.error(t("dashboard.layout.saveFailed"));
    }
  };

  // Another dashboard (or none) means the draft is not for what is on screen any more.
  watch(dashboardKey, cancel);

  return { editing, items, isDirty, saving, conflict, start, cancel, update, persist, overwrite, reload, restoreDefault };
};
