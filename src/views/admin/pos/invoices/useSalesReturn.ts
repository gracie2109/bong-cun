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

  const returnedLines = (lineId: string) =>
    salesReturns.value.flatMap((item) => item.lines).filter((line) => line.invoiceLineId === lineId);
  const returnedQty = (lineId: string): number => returnedLines(lineId).reduce((sum, line) => sum + line.qty, 0);
  const refundedAmount = (lineId: string): number =>
    returnedLines(lineId).reduce((sum, line) => sum + line.amount, 0);

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

  // Same sum as create_sales_return: whole dong for the units returned so far less what earlier
  // returns of the line refunded, never more than is left of the invoice total.
  const refundPreview = computed(() => {
    const current = invoice.value;
    if (!current || current.subtotal === 0) return 0;
    let invoiceRefunded = salesReturns.value.reduce((sum, item) => sum + item.refundAmount, 0);
    let refund = 0;
    for (const { line, qty } of refundLines.value) {
      const paidSoFar = Math.round(
        (((line.amount * (returnedQty(line.id) + qty)) / line.qty) * current.total) / current.subtotal
      );
      const amount = Math.max(0, Math.min(paidSoFar - refundedAmount(line.id), current.total - invoiceRefunded));
      invoiceRefunded += amount;
      refund += amount;
    }
    return refund;
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
