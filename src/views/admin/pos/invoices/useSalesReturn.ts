import { computed, reactive, ref, type Ref } from "vue";
import { useCreateSalesReturn } from "@/queries/pos";
import type { InvoiceDetail, RefundMethod, SalesReturn } from "@/repositories/pos";
import { parseQty } from "@/views/admin/inventory/format";

/** Returning goods from a paid invoice: what can still be returned, the form, and the refund preview. */
export const useSalesReturn = (invoice: Ref<InvoiceDetail | null>, salesReturns: Ref<SalesReturn[]>) => {
  const mutation = useCreateSalesReturn();

  const returning = ref(false);
  const returnQty = reactive<Record<string, string>>({});
  const reason = ref("");
  const refundMethod = ref<RefundMethod>("cash");

  const returnedQty = (lineId: string): number =>
    salesReturns.value
      .flatMap((item) => item.lines)
      .filter((line) => line.invoiceLineId === lineId)
      .reduce((sum, line) => sum + line.qty, 0);

  // Only goods go back: product lines with something left to return.
  const returnableLines = computed(() =>
    (invoice.value?.lines ?? []).filter((line) => line.itemType === "product" && line.qty - returnedQty(line.id) > 0)
  );

  const refundLines = computed(() =>
    returnableLines.value
      .map((line) => ({ line, qty: parseQty(returnQty[line.id] ?? "") }))
      .filter((item) => Number.isFinite(item.qty) && item.qty > 0)
  );

  const invalid = computed(() =>
    returnableLines.value.some((line) => {
      const text = (returnQty[line.id] ?? "").trim();
      if (!text) return false;
      const value = parseQty(text);
      return !Number.isFinite(value) || value < 0 || value > line.qty - returnedQty(line.id);
    })
  );

  // What the database will refund: each line at what was paid for it, the discount spread over the lines.
  const refundPreview = computed(() => {
    const current = invoice.value;
    if (!current || current.subtotal === 0) return 0;
    return refundLines.value.reduce(
      (sum, { line, qty }) => sum + Math.round((line.amount * qty * current.total) / line.qty / current.subtotal),
      0
    );
  });

  const canSubmit = computed(
    () => !!reason.value.trim() && !invalid.value && refundLines.value.length > 0 && !mutation.isPending.value
  );

  const start = () => {
    for (const key of Object.keys(returnQty)) delete returnQty[key];
    reason.value = "";
    refundMethod.value = "cash";
    returning.value = true;
  };

  const submit = async () => {
    if (!invoice.value) return;
    try {
      await mutation.mutateAsync({
        invoiceId: invoice.value.id,
        reason: reason.value.trim(),
        refundMethod: refundMethod.value,
        lines: refundLines.value.map(({ line, qty }) => ({ invoiceLineId: line.id, qty })),
      });
      returning.value = false;
    } catch {
      // the mutation already showed the failure toast
    }
  };

  return {
    returning,
    returnQty,
    reason,
    refundMethod,
    returnedQty,
    returnableLines,
    invalid,
    refundPreview,
    canSubmit,
    start,
    submit,
  };
};
