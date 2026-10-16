import { useDebounceFn } from "@vueuse/core";
import { ref, watch, type Ref } from "vue";
import { clampQty } from "@/utils/shop/cart";

/**
 * A quantity box that follows the cart: typing updates the box at once and the cart 500 ms after
 * the last keystroke; a change from elsewhere (another tab, a stock fix) updates the box.
 */
export const useQtyInput = (qty: Ref<number>, commit: (qty: number) => void) => {
  const draft = ref(qty.value);
  watch(qty, (value) => (draft.value = value));

  const send = useDebounceFn((value: number) => commit(value), 500);

  const set = (value: number) => {
    const next = clampQty(value);
    draft.value = next;
    void send(next);
  };

  return { draft, set };
};
