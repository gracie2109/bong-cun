<template>
  <tr
    class="cursor-pointer border-t hover:bg-muted/40"
    :class="invoice.status === 'cancelled' ? 'text-muted-foreground' : ''"
    @click="emit('open')"
  >
    <td class="px-4 py-3 font-semibold">{{ invoice.code }}</td>
    <td class="whitespace-nowrap px-4 py-3">{{ dateTime(invoice.createdAt) }}</td>
    <td class="px-4 py-3">
      {{ invoice.customerName ?? $t("pos.walkIn") }}
      <span v-if="invoice.customerPhone" class="block text-xs text-muted-foreground">{{ invoice.customerPhone }}</span>
    </td>
    <td class="px-4 py-3">{{ invoice.cashierName }}</td>
    <td class="whitespace-nowrap px-4 py-3 text-right font-semibold" :class="invoice.status === 'cancelled' ? 'line-through' : ''">
      {{ money(invoice.total) }}
    </td>
    <td class="px-4 py-3">
      <InvoiceStatusPill :invoice="invoice" />
    </td>
  </tr>
</template>

<script lang="ts" setup>
import type { Invoice } from "@/repositories/pos";
import { dateTime, money } from "../format";
import InvoiceStatusPill from "./InvoiceStatusPill.vue";

defineProps<{ invoice: Invoice }>();

const emit = defineEmits<{ open: [] }>();
</script>
