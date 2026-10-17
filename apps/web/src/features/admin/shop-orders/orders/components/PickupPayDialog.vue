<template>
  <AppDialog
    v-model:open="open"
    :title="$t('shop.admin.dialogs.collectTitle')"
    :description="$t('shop.admin.dialogs.collectHint')"
    :ok-text="$t('shop.admin.dialogs.collectOk')"
    :ok-disabled="!split.canConfirm.value"
    :busy="busy"
    @ok="$emit('submit', split.entries())"
  >
    <div class="space-y-4">
      <div class="rounded-xl bg-primary/5 p-4 text-center">
        <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">{{ $t("pos.payment.due") }}</p>
        <p class="text-3xl font-bold text-primary">{{ money(total) }}</p>
      </div>

      <div class="space-y-2">
        <Label for="pickup-cash" class="flex items-center gap-2"><Banknote class="size-4" />{{ $t("pos.method.cash") }}</Label>
        <Input id="pickup-cash" v-model="split.cash.value" inputmode="numeric" placeholder="0" />
        <div class="flex flex-wrap gap-1.5">
          <button
            v-for="value in split.suggestions.value"
            :key="value"
            type="button"
            class="rounded-full border px-2.5 py-1 text-xs font-semibold hover:border-primary hover:text-primary"
            @click="split.cash.value = String(value)"
          >
            {{ money(value) }}
          </button>
        </div>
      </div>
      <div class="grid gap-2 sm:grid-cols-2">
        <div class="space-y-2">
          <Label for="pickup-transfer" class="flex items-center gap-2"><Landmark class="size-4" />{{ $t("pos.method.transfer") }}</Label>
          <Input id="pickup-transfer" v-model="split.transfer.value" inputmode="numeric" placeholder="0" />
        </div>
        <div class="space-y-2">
          <Label for="pickup-ref">{{ $t("pos.payment.bankRef") }}</Label>
          <Input id="pickup-ref" v-model="split.bankRef.value" :disabled="!split.transferAmount.value" />
        </div>
      </div>
      <div class="space-y-2">
        <Label for="pickup-card" class="flex items-center gap-2"><CreditCard class="size-4" />{{ $t("pos.method.card") }}</Label>
        <Input id="pickup-card" v-model="split.card.value" inputmode="numeric" placeholder="0" />
      </div>

      <div class="space-y-1 border-t pt-3 text-sm">
        <div v-if="split.paid.value < total" class="flex justify-between text-red-600">
          <span>{{ $t("pos.payment.missing") }}</span>
          <span class="font-semibold">{{ money(total - split.paid.value) }}</span>
        </div>
        <div v-else class="flex justify-between">
          <span class="text-muted-foreground">{{ $t("pos.change") }}</span>
          <span class="font-bold text-primary">{{ money(split.change.value) }}</span>
        </div>
        <p v-if="split.nonCashTooHigh.value" class="text-xs text-red-600">{{ $t("pos.errors.overpaid") }}</p>
      </div>
    </div>
  </AppDialog>
</template>

<script lang="ts" setup>
import { toRef, watch } from "vue";
import { Banknote, CreditCard, Landmark } from "lucide-vue-next";
import AppDialog from "@/components/common/AppDialog.vue";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { money } from "@/features/admin/pos/format";
import { usePaymentSplit, type PaymentEntry } from "@/features/admin/pos";

const props = defineProps<{ total: number; busy: boolean }>();
const open = defineModel<boolean>("open", { required: true });
defineEmits<{ submit: [payments: PaymentEntry[]] }>();

const split = usePaymentSplit(toRef(props, "total"));

// Each time the dialog opens, start with cash for the exact total.
watch(open, (isOpen) => {
  if (isOpen) split.reset();
});
</script>
