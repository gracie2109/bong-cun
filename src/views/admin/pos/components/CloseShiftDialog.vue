<template>
  <AppDialog
    :open="open"
    :title="$t('pos.shift.closeTitle', { code: shift?.code ?? '' })"
    :description="$t('pos.shift.closeSubtitle')"
    :ok-text="$t('pos.shift.close')"
    :ok-disabled="counted === ''"
    :busy="mutation.isPending.value"
    size="lg"
    form-id="close-shift-form"
    @update:open="emit('update:open', $event)"
  >

    <Skeleton v-if="summaryQuery.isPending.value" class="h-40 w-full" />
    <dl v-else-if="summary" class="grid grid-cols-2 gap-x-4 gap-y-1.5 rounded-xl bg-muted/50 p-4 text-sm">
      <dt class="text-muted-foreground">{{ $t("pos.shift.invoices") }}</dt>
      <dd class="text-right font-medium">
        {{ summary.invoiceCount }}
        <span v-if="summary.cancelledCount" class="text-xs text-muted-foreground">
          ({{ $t("pos.shift.cancelledCount", { n: summary.cancelledCount }) }})
        </span>
      </dd>
      <dt class="text-muted-foreground">{{ $t("pos.shift.sales") }}</dt>
      <dd class="text-right font-semibold">{{ money(summary.salesTotal) }}</dd>
      <dt class="text-muted-foreground">{{ $t("pos.method.transfer") }}</dt>
      <dd class="text-right">{{ money(summary.transferIn) }}</dd>
      <dt class="text-muted-foreground">{{ $t("pos.method.card") }}</dt>
      <dd class="text-right">{{ money(summary.cardIn) }}</dd>
      <template v-if="summary.returnCount">
        <dt class="text-muted-foreground">{{ $t("pos.shift.returns", { n: summary.returnCount }) }}</dt>
        <dd class="text-right text-red-600">-{{ money(summary.refundCash + summary.refundTransfer) }}</dd>
      </template>
      <dt class="col-span-2 mt-2 border-t pt-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
        {{ $t("pos.shift.drawer") }}
      </dt>
      <dt class="text-muted-foreground">{{ $t("pos.shift.openingCash") }}</dt>
      <dd class="text-right">{{ money(summary.openingCash) }}</dd>
      <dt class="text-muted-foreground">{{ $t("pos.shift.cashIn") }}</dt>
      <dd class="text-right">{{ money(summary.cashIn) }}</dd>
      <dt class="text-muted-foreground">{{ $t("pos.shift.changeOut") }}</dt>
      <dd class="text-right">-{{ money(summary.changeTotal) }}</dd>
      <template v-if="summary.refundCash">
        <dt class="text-muted-foreground">{{ $t("pos.shift.refundCash") }}</dt>
        <dd class="text-right">-{{ money(summary.refundCash) }}</dd>
      </template>
      <dt class="font-semibold">{{ $t("pos.shift.expectedCash") }}</dt>
      <dd class="text-right font-bold text-primary">{{ money(summary.expectedCash) }}</dd>
    </dl>

    <form id="close-shift-form" class="space-y-4" @submit.prevent="submit">
      <div class="space-y-2">
        <Label for="counted-cash">{{ $t("pos.shift.countedCash") }}</Label>
        <Input id="counted-cash" v-model="counted" inputmode="numeric" placeholder="0" />
        <p
          v-if="summary && counted !== ''"
          class="text-sm font-medium"
          :class="difference === 0 ? 'text-primary' : 'text-red-600'"
        >
          {{
            difference === 0
              ? $t("pos.shift.balanced")
              : $t(difference > 0 ? "pos.shift.over" : "pos.shift.short", { amount: money(Math.abs(difference)) })
          }}
        </p>
      </div>
      <div class="space-y-2">
        <Label for="close-note">{{ $t("pos.shift.note") }}</Label>
        <Input id="close-note" v-model="note" />
      </div>
    </form>
  </AppDialog>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Skeleton } from "@/components/ui/skeleton";
import { useCloseShift, useShiftSummary } from "@/queries/pos";
import type { CashShift } from "@/repositories/pos";
import { money, parseAmount } from "../format";

const props = defineProps<{ open: boolean; shift: CashShift | null }>();
const emit = defineEmits<{ "update:open": [value: boolean]; closed: [] }>();

const counted = ref("");
const note = ref("");
const mutation = useCloseShift();
const summaryQuery = useShiftSummary(
  computed(() => props.shift?.id),
  computed(() => props.open)
);
const summary = computed(() => summaryQuery.data.value);
const difference = computed(() => parseAmount(counted.value) - (summary.value?.expectedCash ?? 0));

watch(
  () => props.open,
  (open) => {
    if (!open) return;
    counted.value = "";
    note.value = "";
    void summaryQuery.refetch();
  }
);

const submit = async () => {
  if (!props.shift) return;
  try {
    await mutation.mutateAsync({
      shiftId: props.shift.id,
      countedCash: parseAmount(counted.value),
      note: note.value.trim(),
    });
    emit("update:open", false);
    emit("closed");
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
