import { computed, ref, type Ref } from "vue";
import type { PaymentMethod } from "@/repositories/pos";
import { cashSuggestions, parseAmount } from "./format";

export type PaymentEntry = { method: PaymentMethod; amount: number; bankRef?: string | null };

/** How a sale is paid: cash, transfer and card amounts, what is still due, and the change. */
export const usePaymentSplit = (total: Ref<number>) => {
  const cash = ref("");
  const transfer = ref("");
  const card = ref("");
  const bankRef = ref("");

  const cashAmount = computed(() => parseAmount(cash.value));
  const transferAmount = computed(() => parseAmount(transfer.value));
  const cardAmount = computed(() => parseAmount(card.value));
  const paid = computed(() => cashAmount.value + transferAmount.value + cardAmount.value);
  const change = computed(() => Math.max(0, paid.value - total.value));
  // Only cash can be handed back; transfer and card together may not exceed the total.
  const nonCashTooHigh = computed(() => transferAmount.value + cardAmount.value > total.value);
  const canConfirm = computed(() => paid.value >= total.value && !nonCashTooHigh.value);
  const suggestions = computed(() =>
    cashSuggestions(Math.max(0, total.value - transferAmount.value - cardAmount.value))
  );

  /** Starts a new sale: cash for the exact total, nothing else. */
  const reset = () => {
    cash.value = String(total.value);
    transfer.value = "";
    card.value = "";
    bankRef.value = "";
  };

  /** The non-zero payments to send. */
  const entries = (): PaymentEntry[] =>
    [
      { method: "cash", amount: cashAmount.value },
      { method: "transfer", amount: transferAmount.value, bankRef: bankRef.value.trim() || null },
      { method: "card", amount: cardAmount.value },
    ].filter((entry): entry is PaymentEntry => entry.amount > 0);

  return {
    cash,
    transfer,
    card,
    bankRef,
    transferAmount,
    paid,
    change,
    nonCashTooHigh,
    canConfirm,
    suggestions,
    reset,
    entries,
  };
};
