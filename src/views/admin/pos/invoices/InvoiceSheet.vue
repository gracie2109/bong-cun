<template>
  <Sheet :open="!!invoiceId" @update:open="(open) => !open && emit('close')">
    <SheetContent side="right" class="flex w-full flex-col gap-0 p-0 sm:max-w-lg">
      <SheetHeader class="border-b px-6 py-4">
        <SheetTitle class="flex items-center gap-2">
          {{ invoice?.code ?? $t("pos.invoices.detail") }}
          <span
            v-if="invoice"
            class="rounded-full px-2 py-0.5 text-[11px] font-semibold"
            :class="invoice.status === 'paid' ? 'bg-primary/10 text-primary' : 'bg-red-50 text-red-600'"
          >
            {{ $t(`pos.status.${invoice.status}`) }}
          </span>
        </SheetTitle>
        <SheetDescription>{{ invoice ? dateTime(invoice.createdAt) : "" }}</SheetDescription>
      </SheetHeader>

      <div class="flex-1 space-y-5 overflow-y-auto px-6 py-5">
        <Skeleton v-if="invoiceQuery.isPending.value" class="h-60 w-full" />
        <template v-else-if="invoice">
          <dl class="grid grid-cols-2 gap-y-1 text-sm">
            <dt class="text-muted-foreground">{{ $t("pos.receipt.customer") }}</dt>
            <dd class="text-right">
              {{ invoice.customerName ?? $t("pos.walkIn") }}
              <span v-if="invoice.customerPhone" class="block text-xs text-muted-foreground">{{ invoice.customerPhone }}</span>
            </dd>
            <dt class="text-muted-foreground">{{ $t("pos.receipt.cashier") }}</dt>
            <dd class="text-right">{{ invoice.cashierName }}</dd>
            <template v-if="invoice.note">
              <dt class="text-muted-foreground">{{ $t("pos.cart.note") }}</dt>
              <dd class="text-right">{{ invoice.note }}</dd>
            </template>
          </dl>

          <InvoiceItemsTable :lines="invoice.lines" :returned-qty="returnedQty" />

          <InvoiceTotals :invoice="invoice" />

          <div v-if="invoice.status === 'cancelled'" class="rounded-lg bg-red-50 p-3 text-sm text-red-700">
            {{ $t("pos.invoices.cancelledAt", { time: dateTime(invoice.cancelledAt) }) }}
            <span class="block">{{ invoice.cancelReason }}</span>
          </div>

          <InvoiceReturnsList v-if="salesReturns.length" :sales-returns="salesReturns" />

          <InvoiceReturnForm
            v-if="returning"
            v-model:quantities="returnQty"
            v-model:reason="returnReason"
            v-model:refund-method="refundMethod"
            :lines="returnableLines"
            :returned-qty="returnedQty"
            :invalid="returnInvalid"
            :refund-preview="refundPreview"
            :can-submit="canSubmitReturn"
            @cancel="returning = false"
            @submit="submitReturn"
          />

          <InvoiceCancelForm
            v-if="cancelling"
            v-model:reason="reason"
            :pending="cancelMutation.isPending.value"
            @dismiss="cancelling = false"
            @confirm="cancel"
          />
        </template>
      </div>

      <SheetFooter v-if="invoice" class="gap-2 border-t px-6 py-4">
        <Button
          v-if="canDelete && invoice.status === 'paid' && !cancelling && !returning && salesReturns.length === 0"
          variant="outline"
          class="text-red-600"
          @click="cancelling = true"
        >
          {{ $t("pos.invoices.cancel") }}
        </Button>
        <Button
          v-if="canDelete && invoice.status === 'paid' && !cancelling && !returning && returnableLines.length"
          variant="outline"
          @click="startReturn"
        >
          <Undo2 class="mr-2 size-4" />
          {{ $t("pos.returns.start") }}
        </Button>
        <Button @click="printReceipt(invoice, branch, t)">
          <Printer class="mr-2 size-4" />
          {{ $t("pos.payment.print") }}
        </Button>
      </SheetFooter>
    </SheetContent>
  </Sheet>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { useI18n } from "vue-i18n";
import { Printer, Undo2 } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { Skeleton } from "@/components/ui/skeleton";
import { usePermission } from "@/composables/usePermission";
import { useCancelInvoice, useInvoice, useInvoiceReturns } from "@/queries/pos";
import type { Branch } from "@/repositories/branches";
import { dateTime } from "../format";
import { printReceipt } from "../receipt";
import InvoiceCancelForm from "./InvoiceCancelForm.vue";
import InvoiceItemsTable from "./InvoiceItemsTable.vue";
import InvoiceReturnForm from "./InvoiceReturnForm.vue";
import InvoiceReturnsList from "./InvoiceReturnsList.vue";
import InvoiceTotals from "./InvoiceTotals.vue";
import { useSalesReturn } from "./useSalesReturn";

const props = defineProps<{ invoiceId: string | undefined; branch: Branch | null }>();
const emit = defineEmits<{ close: [] }>();

const { t } = useI18n();
const { canDelete } = usePermission("pos");
const invoiceQuery = useInvoice(computed(() => props.invoiceId));
const invoice = computed(() => invoiceQuery.data.value ?? null);
const returnsQuery = useInvoiceReturns(computed(() => props.invoiceId));
const salesReturns = computed(() => returnsQuery.data.value ?? []);

const cancelMutation = useCancelInvoice();
const cancelling = ref(false);
const reason = ref("");

const {
  returning,
  returnQty,
  reason: returnReason,
  refundMethod,
  returnedQty,
  returnableLines,
  invalid: returnInvalid,
  refundPreview,
  canSubmit: canSubmitReturn,
  start: startReturn,
  submit: submitReturn,
} = useSalesReturn(invoice, salesReturns);

watch(
  () => props.invoiceId,
  () => {
    cancelling.value = false;
    reason.value = "";
    returning.value = false;
  }
);

const cancel = async () => {
  if (!invoice.value) return;
  try {
    await cancelMutation.mutateAsync({ id: invoice.value.id, reason: reason.value.trim() });
    cancelling.value = false;
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
