<template>
  <AppDialog
    :open="open"
    :title="$t('pos.payment.title')"
    :description="$t('pos.payment.subtitle')"
    :ok-text="$t('pos.payment.confirm')"
    :ok-disabled="!canConfirm"
    :busy="busy"
    :hide-header="!!result"
    :hide-footer="!!result"
    @update:open="onOpenChange"
    @ok="confirm"
  >
    <PaymentSuccess v-if="result" :result="result" :printing="printing" @print="emit('print')" @new-sale="emit('update:open', false)" />

    <div v-else class="contents" @keydown="guardScan">
      <div class="rounded-xl bg-primary/5 p-4 text-center">
        <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">{{ $t("pos.payment.due") }}</p>
        <p class="text-3xl font-bold text-primary">{{ money(total) }}</p>
      </div>

      <div class="space-y-4">
        <div class="space-y-2">
          <Label for="pay-cash" class="flex items-center gap-2"><Banknote class="size-4" />{{ $t("pos.method.cash") }}</Label>
          <Input id="pay-cash" v-model="cash" inputmode="numeric" placeholder="0" />
          <div class="flex flex-wrap gap-1.5">
            <button
              v-for="value in suggestions"
              :key="value"
              type="button"
              class="rounded-full border px-2.5 py-1 text-xs font-semibold hover:border-primary hover:text-primary"
              @click="cash = String(value)"
            >
              {{ money(value) }}
            </button>
          </div>
        </div>
        <div class="grid gap-2 sm:grid-cols-[1fr_1fr]">
          <div class="space-y-2">
            <Label for="pay-transfer" class="flex items-center gap-2"><Landmark class="size-4" />{{ $t("pos.method.transfer") }}</Label>
            <Input id="pay-transfer" v-model="transfer" inputmode="numeric" placeholder="0" />
          </div>
          <div class="space-y-2">
            <Label for="pay-ref">{{ $t("pos.payment.bankRef") }}</Label>
            <Input id="pay-ref" v-model="bankRef" :disabled="!transferAmount" />
          </div>
        </div>
        <div class="space-y-2">
          <Label for="pay-card" class="flex items-center gap-2"><CreditCard class="size-4" />{{ $t("pos.method.card") }}</Label>
          <Input id="pay-card" v-model="card" inputmode="numeric" placeholder="0" />
        </div>
      </div>

      <div class="space-y-1 border-t pt-3 text-sm">
        <div class="flex justify-between">
          <span class="text-muted-foreground">{{ $t("pos.payment.paid") }}</span>
          <span class="font-semibold">{{ money(paid) }}</span>
        </div>
        <div v-if="paid < total" class="flex justify-between text-red-600">
          <span>{{ $t("pos.payment.missing") }}</span>
          <span class="font-semibold">{{ money(total - paid) }}</span>
        </div>
        <div v-else class="flex justify-between">
          <span class="text-muted-foreground">{{ $t("pos.change") }}</span>
          <span class="font-bold text-primary">{{ money(change) }}</span>
        </div>
        <p v-if="nonCashTooHigh" class="text-xs text-red-600">{{ $t("pos.errors.overpaid") }}</p>
      </div>
    </div>
  </AppDialog>
</template>

<script lang="ts" setup>
import { toRef, watch } from "vue";
import { useI18n } from "vue-i18n";
import { Banknote, CreditCard, Landmark } from "lucide-vue-next";
import { toast } from "vue-sonner";
import AppDialog from "@/components/common/AppDialog.vue";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import type { SaleResult } from "@/repositories/pos";
import { money } from "../format";
import { usePaymentSplit, type PaymentEntry } from "../usePaymentSplit";
import { useScanGuard } from "../useScanGuard";
import PaymentSuccess from "./PaymentSuccess.vue";

const props = defineProps<{
  open: boolean;
  total: number;
  busy: boolean;
  printing: boolean;
  result: SaleResult | null;
}>();
const emit = defineEmits<{
  "update:open": [value: boolean];
  confirm: [payments: PaymentEntry[]];
  print: [];
}>();

const { cash, transfer, card, bankRef, transferAmount, paid, change, nonCashTooHigh, canConfirm, suggestions, reset, entries } =
  usePaymentSplit(toRef(props, "total"));

const { t } = useI18n();
// A barcode scanned while this dialog is open must not land in an amount and confirm the sale.
const guardScan = useScanGuard(
  () => ({ cash: cash.value, transfer: transfer.value, card: card.value, bankRef: bankRef.value }),
  (saved) => {
    cash.value = saved.cash;
    transfer.value = saved.transfer;
    card.value = saved.card;
    bankRef.value = saved.bankRef;
  },
  () => toast.warning(t("pos.payment.scanBlocked"))
);

// Each time the dialog opens for a new sale, start with cash = the exact total.
watch(
  () => props.open,
  (open) => {
    if (open && !props.result) reset();
  }
);

const confirm = () => emit("confirm", entries());

const onOpenChange = (value: boolean) => {
  if (!props.busy) emit("update:open", value);
};
</script>
