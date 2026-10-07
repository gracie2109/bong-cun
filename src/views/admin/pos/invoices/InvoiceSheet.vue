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
                <td class="py-2 text-right">{{ line.qty }}</td>
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
          v-if="canDelete && invoice.status === 'paid' && !cancelling"
          variant="outline"
          class="text-red-600"
          @click="cancelling = true"
        >
          {{ $t("pos.invoices.cancel") }}
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
import { Printer } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
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
import { useCancelInvoice, useInvoice } from "@/queries/pos";
import type { Branch } from "@/repositories/branches";
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

watch(
  () => props.invoiceId,
  () => {
    cancelling.value = false;
    reason.value = "";
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
