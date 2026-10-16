<template>
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
</template>

<script lang="ts" setup>
import type { InvoiceDetail } from "@/repositories/pos";
import { money } from "../format";

defineProps<{ invoice: InvoiceDetail }>();
</script>
