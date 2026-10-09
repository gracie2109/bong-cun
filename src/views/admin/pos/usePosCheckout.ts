import { ref, watch, type Ref } from "vue";
import { useI18n } from "vue-i18n";
import { supabaseClient } from "@/lib/supabase";
import { useCreateInvoice } from "@/queries/pos";
import { getInvoice, type SaleCustomer, type SaleResult } from "@/repositories/pos";
import type { Branch } from "@/repositories/branches";
import type { Buyer } from "./components/CustomerPanel.vue";
import type { PaymentEntry } from "./usePaymentSplit";
import type { CartLine } from "./usePosCart";
import { printReceipt } from "./receipt";

type Sale = {
  branchId: Ref<string | undefined>;
  branch: Ref<Branch | null>;
  buyer: Ref<Buyer | null>;
  lines: Ref<CartLine[]>;
  discount: Ref<number>;
  note: Ref<string>;
  /** Clears the cart to start the next sale. */
  reset: () => void;
};

const toSaleCustomer = (value: Buyer | null): SaleCustomer => {
  if (!value) return null;
  if (value.customerId) return { id: value.customerId };
  if (value.userId) return { userId: value.userId };
  return { fullName: value.fullName, phone: value.phone };
};

/** Paying for the cart, printing the receipt, and starting the next sale once the dialog closes. */
export const usePosCheckout = (sale: Sale) => {
  const { t } = useI18n();

  const paymentOpen = ref(false);
  const result = ref<SaleResult | null>(null);
  const printing = ref(false);
  const createMutation = useCreateInvoice();
  // One per sale: paying again after an error resends it, so a sale that did go through is not made twice.
  let clientRef = crypto.randomUUID();

  const pay = async (payments: PaymentEntry[]) => {
    if (!sale.branchId.value) return;
    try {
      result.value = await createMutation.mutateAsync({
        branchId: sale.branchId.value,
        customer: toSaleCustomer(sale.buyer.value),
        discountAmount: sale.discount.value,
        note: sale.note.value.trim() || null,
        lines: sale.lines.value.map((line) => ({
          type: line.item.type,
          id: line.item.id,
          qty: line.qty,
          petId: line.petId,
        })),
        payments,
        clientRef,
      });
    } catch {
      // the mutation already showed the failure toast
    }
  };

  const print = async () => {
    if (!result.value) return;
    printing.value = true;
    try {
      const invoice = await getInvoice(supabaseClient(), result.value.id);
      if (invoice) printReceipt(invoice, sale.branch.value, t);
    } finally {
      printing.value = false;
    }
  };

  // Closing the dialog after a sale starts the next one.
  watch(paymentOpen, (open) => {
    if (open || !result.value) return;
    result.value = null;
    clientRef = crypto.randomUUID();
    sale.reset();
  });

  return { paymentOpen, result, printing, creating: createMutation.isPending, pay, print };
};
