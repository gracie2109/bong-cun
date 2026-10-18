import { ref } from "vue";
import { toast } from "vue-sonner";
import i18n from "@/i18n";
import { useDeleteProductGroups } from "@/features/shared/products";

/** Asks before deleting product groups, then reports how many were removed and how many were kept. */
export const useProductDelete = (onDeleted: (ids: string[]) => void) => {
  const t = i18n.global.t;
  const mutation = useDeleteProductGroups();
  const pendingIds = ref<string[]>([]);

  const ask = (ids: string[]) => {
    pendingIds.value = ids;
  };
  const cancel = () => {
    pendingIds.value = [];
  };

  const confirm = async () => {
    const ids = pendingIds.value;
    pendingIds.value = [];
    if (ids.length === 0) return;
    try {
      const { deleted, blocked } = await mutation.mutateAsync(ids);
      onDeleted(deleted);
      if (deleted.length > 0) toast.success(t("products.delete.done", { n: deleted.length }));
      if (blocked.length > 0) {
        const sold = blocked.filter((item) => item.reason === "sold").length;
        toast.warning(t("products.delete.kept", { n: blocked.length, sold, stocked: blocked.length - sold }));
      }
    } catch {
      // the mutation already showed the failure toast
    }
  };

  return { pendingIds, deleting: mutation.isPending, ask, cancel, confirm };
};
