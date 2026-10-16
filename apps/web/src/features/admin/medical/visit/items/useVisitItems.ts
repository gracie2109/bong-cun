import { computed, ref, type Ref } from "vue";
import i18n from "@/i18n";
import { sendMessageToast } from "@/lib/utils";
import { useAddItem, useRemoveItem, useUpdateItem } from "@/queries/medicalVisits";
import type { ItemInput, MedicalVisitDetail } from "@bongcun/core/medical";

/** The lines of one visit: who may change them, the dialogs, and the actions on a line. */
export const useVisitItems = (visit: Ref<MedicalVisitDetail>, canUpdate: Ref<boolean>) => {
  // Lines can be added to an open case and to a signed one until the cashier has billed them.
  const canEdit = computed(() => canUpdate.value && ["in_progress", "done", "paid"].includes(visit.value.status));

  const serviceOpen = ref(false);
  const drugOpen = ref(false);
  const prescriptionOpen = ref(false);

  const billable = computed(() => visit.value.items.filter((item) => item.kind !== "external"));
  const total = computed(() => billable.value.reduce((sum, item) => sum + item.amount, 0));

  const adding = useAddItem();
  const updating = useUpdateItem();
  const removing = useRemoveItem();

  const warnLowStock = (warnings: string[]) => {
    if (warnings.includes("low_stock")) sendMessageToast("fail", "update", "error", i18n.global.t("medical.items.lowStock"));
  };

  /** Adds a line; true when it went in (the dialog then closes). */
  const add = async (input: ItemInput): Promise<boolean> => {
    try {
      const result = await adding.mutateAsync({ visitId: visit.value.id, input });
      warnLowStock(result.warnings);
      return true;
    } catch {
      return false;
    }
  };

  const changeQty = async (id: string, qty: number) => {
    try {
      warnLowStock((await updating.mutateAsync({ id, patch: { qty } })).warnings);
    } catch {
      // the mutation already showed the failure toast
    }
  };

  const remove = (id: string) => removing.mutate(id);

  return {
    canEdit, serviceOpen, drugOpen, prescriptionOpen, billable, total, add, changeQty, remove,
    saving: computed(() => adding.isPending.value),
  };
};
