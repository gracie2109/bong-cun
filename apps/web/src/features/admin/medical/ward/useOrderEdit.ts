import { ref } from "vue";
import type { WardOrder } from "@bongcun/core/medical";

/** Which order the vet is editing, replacing with another medicine, or stopping; one dialog at a time. */
export const useOrderEdit = () => {
  const editOrder = ref<WardOrder | null>(null);
  const replaceOrder = ref<WardOrder | null>(null);
  const stopOrder = ref<WardOrder | null>(null);
  return { editOrder, replaceOrder, stopOrder };
};
