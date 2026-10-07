<template>
  <Dialog :open="open" @update:open="onOpenChange">
    <DialogContent class="sm:max-w-lg">
      <template v-if="result">
        <DialogHeader>
          <DialogTitle class="flex items-center gap-2">
            <CircleCheck class="size-5 text-primary" />
            {{ $t("pos.payment.done") }}
          </DialogTitle>
          <DialogDescription>{{ result.code }}</DialogDescription>
        </DialogHeader>
        <div class="space-y-2 rounded-xl bg-muted/50 p-4">
          <div class="flex justify-between text-sm">
            <span class="text-muted-foreground">{{ $t("pos.total") }}</span>
            <span class="font-semibold">{{ money(result.total) }}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-muted-foreground">{{ $t("pos.change") }}</span>
            <span class="text-2xl font-bold text-primary">{{ money(result.changeAmount) }}</span>
          </div>
        </div>
        <DialogFooter class="gap-2">
          <Button variant="outline" :disabled="printing" @click="emit('print')">
            <Printer class="mr-2 size-4" />
            {{ $t("pos.payment.print") }}
          </Button>
          <Button @click="emit('update:open', false)">{{ $t("pos.payment.newSale") }}</Button>
        </DialogFooter>
      </template>

      <template v-else>
        <DialogHeader>
          <DialogTitle>{{ $t("pos.payment.title") }}</DialogTitle>
          <DialogDescription>{{ $t("pos.payment.subtitle") }}</DialogDescription>
        </DialogHeader>

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

        <DialogFooter class="gap-2">
          <Button variant="outline" @click="emit('update:open', false)">{{ $t("petCare.common.cancel") }}</Button>
          <Button :disabled="!canConfirm || busy" @click="confirm">
            <Loader2 v-if="busy" class="mr-2 size-4 animate-spin" />
            {{ $t("pos.payment.confirm") }}
          </Button>
        </DialogFooter>
      </template>
    </DialogContent>
  </Dialog>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { Banknote, CircleCheck, CreditCard, Landmark, Loader2, Printer } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import type { PaymentMethod, SaleResult } from "@/repositories/pos";
import { cashSuggestions, money, parseAmount } from "../format";

export type PaymentEntry = { method: PaymentMethod; amount: number; bankRef?: string | null };

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

const cash = ref("");
const transfer = ref("");
const card = ref("");
const bankRef = ref("");

// Each time the dialog opens for a new sale, start with cash = the exact total.
watch(
  () => props.open,
  (open) => {
    if (!open || props.result) return;
    cash.value = String(props.total);
    transfer.value = "";
    card.value = "";
    bankRef.value = "";
  }
);

const cashAmount = computed(() => parseAmount(cash.value));
const transferAmount = computed(() => parseAmount(transfer.value));
const cardAmount = computed(() => parseAmount(card.value));
const paid = computed(() => cashAmount.value + transferAmount.value + cardAmount.value);
const change = computed(() => Math.max(0, paid.value - props.total));
// Only cash can be handed back; transfer and card together may not exceed the total.
const nonCashTooHigh = computed(() => transferAmount.value + cardAmount.value > props.total);
const canConfirm = computed(() => paid.value >= props.total && !nonCashTooHigh.value);
const suggestions = computed(() => cashSuggestions(Math.max(0, props.total - transferAmount.value - cardAmount.value)));

const confirm = () => {
  const entries: PaymentEntry[] = [
    { method: "cash", amount: cashAmount.value },
    { method: "transfer", amount: transferAmount.value, bankRef: bankRef.value.trim() || null },
    { method: "card", amount: cardAmount.value },
  ];
  emit("confirm", entries.filter((entry) => entry.amount > 0));
};

const onOpenChange = (value: boolean) => {
  if (!props.busy) emit("update:open", value);
};
</script>
