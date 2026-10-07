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

          <table class="w-full text-sm">
            <thead>
              <tr class="border-b text-left text-[11px] uppercase tracking-wide text-muted-foreground">
                <th class="py-2 font-semibold">{{ $t("pos.invoices.item") }}</th>
                <th class="py-2 text-right font-semibold">{{ $t("pos.invoices.qty") }}</th>
                <th class="py-2 text-right font-semibold">{{ $t("pos.invoices.amount") }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="line in invoice.lines" :key="line.id" class="border-b last:border-0">
                <td class="py-2">
                  <p class="font-medium">{{ line.name }}</p>
                  <p class="text-xs text-muted-foreground">
                    {{ money(line.unitPrice) }}
                    <template v-if="line.petName"> · {{ line.petName }}</template>
                    <template v-if="line.weightKg"> · {{ line.weightKg }} kg</template>
                  </p>
                </td>
                <td class="py-2 text-right">
                  {{ line.qty }}
                  <span v-if="returnedQty(line.id)" class="block text-[11px] text-red-600">
                    {{ $t("pos.returns.returnedQty", { n: returnedQty(line.id) }) }}
                  </span>
                </td>
                <td class="py-2 text-right font-medium">{{ money(line.amount) }}</td>
              </tr>
            </tbody>
          </table>

          <dl class="space-y-1 rounded-xl bg-muted/50 p-4 text-sm">
            <div class="flex justify-between"><dt>{{ $t("pos.subtotal") }}</dt><dd>{{ money(invoice.subtotal) }}</dd></div>
            <div v-if="invoice.discountAmount" class="flex justify-between">
              <dt>{{ $t("pos.discount") }}</dt><dd>-{{ money(invoice.discountAmount) }}</dd>
            </div>
            <div class="flex justify-between text-base font-bold">
              <dt>{{ $t("pos.total") }}</dt><dd class="text-primary">{{ money(invoice.total) }}</dd>
            </div>
            <div v-for="payment in invoice.payments" :key="payment.id" class="flex justify-between text-muted-foreground">
              <dt>{{ $t(`pos.method.${payment.method}`) }}<template v-if="payment.bankRef"> · {{ payment.bankRef }}</template></dt>
              <dd>{{ money(payment.amount) }}</dd>
            </div>
            <div v-if="invoice.changeAmount" class="flex justify-between text-muted-foreground">
              <dt>{{ $t("pos.change") }}</dt><dd>{{ money(invoice.changeAmount) }}</dd>
            </div>
          </dl>

          <div v-if="invoice.status === 'cancelled'" class="rounded-lg bg-red-50 p-3 text-sm text-red-700">
            {{ $t("pos.invoices.cancelledAt", { time: dateTime(invoice.cancelledAt) }) }}
            <span class="block">{{ invoice.cancelReason }}</span>
          </div>

          <section v-if="salesReturns.length" class="space-y-2">
            <h3 class="text-sm font-semibold">{{ $t("pos.returns.title") }}</h3>
            <div v-for="item in salesReturns" :key="item.id" class="space-y-1 rounded-lg border p-3 text-sm">
              <div class="flex justify-between gap-3">
                <span class="font-semibold">{{ item.code }}</span>
                <span class="font-semibold text-red-600">-{{ money(item.refundAmount) }}</span>
              </div>
              <p class="text-xs text-muted-foreground">
                {{ dateTime(item.createdAt) }} · {{ item.createdByName }} · {{ $t(`pos.method.${item.refundMethod}`) }}
              </p>
              <p v-for="line in item.lines" :key="line.invoiceLineId" class="text-xs">{{ line.qty }} × {{ line.name }}</p>
              <p class="text-xs text-muted-foreground">{{ item.reason }}</p>
            </div>
          </section>

          <div v-if="returning" class="space-y-3 rounded-lg border border-amber-200 p-3">
            <p class="text-sm font-semibold">{{ $t("pos.returns.formTitle") }}</p>
            <div v-for="line in returnableLines" :key="line.id" class="flex items-center justify-between gap-3 text-sm">
              <span class="min-w-0">
                <span class="block truncate font-medium">{{ line.name }}</span>
                <span class="text-xs text-muted-foreground">{{ $t("pos.returns.canReturn", { n: line.qty - returnedQty(line.id) }) }}</span>
              </span>
              <Input v-model="returnQty[line.id]" inputmode="decimal" class="h-8 w-20 text-right" placeholder="0" />
            </div>
            <div class="flex flex-wrap gap-2">
              <Button
                v-for="method in REFUND_METHODS"
                :key="method"
                type="button"
                size="sm"
                :variant="refundMethod === method ? 'default' : 'outline'"
                @click="refundMethod = method"
              >
                {{ $t(`pos.method.${method}`) }}
              </Button>
            </div>
            <div class="space-y-2">
              <Label for="return-reason">{{ $t("pos.returns.reason") }}</Label>
              <Textarea id="return-reason" v-model="returnReason" rows="2" class="resize-none" />
            </div>
            <p v-if="returnInvalid" class="text-sm text-red-600">{{ $t("pos.returns.invalidQty") }}</p>
            <div class="flex items-center justify-between gap-2">
              <span class="text-sm">{{ $t("pos.returns.refund") }} <b class="text-red-600">{{ money(refundPreview) }}</b></span>
              <div class="flex gap-2">
                <Button variant="outline" size="sm" @click="returning = false">{{ $t("petCare.common.cancel") }}</Button>
                <Button
                  size="sm"
                  :disabled="!returnReason.trim() || returnInvalid || refundLines.length === 0 || returnMutation.isPending.value"
                  @click="submitReturn"
                >
                  {{ $t("pos.returns.confirm") }}
                </Button>
              </div>
            </div>
          </div>

          <div v-if="cancelling" class="space-y-2 rounded-lg border border-red-200 p-3">
            <Label for="cancel-reason">{{ $t("pos.invoices.cancelReason") }}</Label>
            <Textarea id="cancel-reason" v-model="reason" rows="2" class="resize-none" />
            <div class="flex justify-end gap-2">
              <Button variant="outline" size="sm" @click="cancelling = false">{{ $t("petCare.common.cancel") }}</Button>
              <Button variant="destructive" size="sm" :disabled="!reason.trim() || cancelMutation.isPending.value" @click="cancel">
                {{ $t("pos.invoices.confirmCancel") }}
              </Button>
            </div>
          </div>
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
import { computed, reactive, ref, watch } from "vue";
import { useI18n } from "vue-i18n";
import { Printer, Undo2 } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { Skeleton } from "@/components/ui/skeleton";
import { Textarea } from "@/components/ui/textarea";
import { usePermission } from "@/composables/usePermission";
import { useCancelInvoice, useCreateSalesReturn, useInvoice, useInvoiceReturns } from "@/queries/pos";
import type { Branch } from "@/repositories/branches";
import { REFUND_METHODS, type RefundMethod } from "@/repositories/pos";
import { parseQty } from "@/views/admin/inventory/format";
import { dateTime, money } from "../format";
import { printReceipt } from "../receipt";

const props = defineProps<{ invoiceId: string | undefined; branch: Branch | null }>();
const emit = defineEmits<{ close: [] }>();

const { t } = useI18n();
const { canDelete } = usePermission("pos");
const invoiceQuery = useInvoice(computed(() => props.invoiceId));
const invoice = computed(() => invoiceQuery.data.value ?? null);
const cancelMutation = useCancelInvoice();
const cancelling = ref(false);
const reason = ref("");
const returnsQuery = useInvoiceReturns(computed(() => props.invoiceId));
const salesReturns = computed(() => returnsQuery.data.value ?? []);
const returnMutation = useCreateSalesReturn();
const returning = ref(false);
const returnQty = reactive<Record<string, string>>({});
const returnReason = ref("");
const refundMethod = ref<RefundMethod>("cash");

watch(
  () => props.invoiceId,
  () => {
    cancelling.value = false;
    reason.value = "";
    returning.value = false;
  }
);

const returnedQty = (lineId: string) =>
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

const returnInvalid = computed(() =>
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

const startReturn = () => {
  for (const key of Object.keys(returnQty)) delete returnQty[key];
  returnReason.value = "";
  refundMethod.value = "cash";
  returning.value = true;
};

const submitReturn = async () => {
  if (!invoice.value) return;
  try {
    await returnMutation.mutateAsync({
      invoiceId: invoice.value.id,
      reason: returnReason.value.trim(),
      refundMethod: refundMethod.value,
      lines: refundLines.value.map(({ line, qty }) => ({ invoiceLineId: line.id, qty })),
    });
    returning.value = false;
  } catch {
    // the mutation already showed the failure toast
  }
};

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
