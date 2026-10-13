<template>
  <span class="inline-flex items-center gap-1">
    <span class="rounded-full px-2 py-0.5 text-[11px] font-semibold" :class="TONE[invoice.status]">
      {{ $t(`pos.status.${invoice.status}`) }}
    </span>
    <span v-if="invoice.channel === 'online'" class="rounded-full bg-violet-100 px-2 py-0.5 text-[11px] font-semibold text-violet-700">
      {{ $t("pos.channel.online") }}
    </span>
  </span>
</template>

<script lang="ts" setup>
import type { Invoice, InvoiceStatus } from "@/repositories/pos";

defineProps<{ invoice: Pick<Invoice, "status" | "channel"> }>();

const TONE: Record<InvoiceStatus, string> = {
  paid: "bg-primary/10 text-primary",
  unpaid: "bg-amber-100 text-amber-800",
  cancelled: "bg-red-50 text-red-600",
};
</script>
