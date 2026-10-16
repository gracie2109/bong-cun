<template>
  <tr
    class="cursor-pointer border-t hover:bg-muted/40"
    :class="row.status === 'cancelled' ? 'text-muted-foreground' : ''"
    @click="emit('open')"
  >
    <td class="px-4 py-3 font-semibold">{{ row.code }}</td>
    <td class="px-4 py-3">{{ $t(`inventory.documents.types.${row.docType}`) }}</td>
    <td class="whitespace-nowrap px-4 py-3">{{ dateTime(row.postedAt ?? row.createdAt) }}</td>
    <td class="max-w-64 px-4 py-3">
      <span class="line-clamp-1">{{ row.supplierName ?? row.note ?? "—" }}</span>
      <span v-if="row.supplierRef" class="block text-xs text-muted-foreground">{{ row.supplierRef }}</span>
    </td>
    <td class="px-4 py-3">{{ row.postedByName ?? row.createdByName }}</td>
    <td class="whitespace-nowrap px-4 py-3 text-right font-semibold">{{ row.status === "draft" ? "—" : money(row.totalCost) }}</td>
    <td class="px-4 py-3">
      <span class="rounded-full px-2 py-0.5 text-[11px] font-semibold" :class="DOC_STATUS_TONE[row.status]">
        {{ $t(`inventory.documents.status.${row.status}`) }}
      </span>
    </td>
  </tr>
</template>

<script lang="ts" setup>
import type { StockDocument } from "@/repositories/inventory";
import { dateTime, money } from "@/views/admin/pos/format";
import { DOC_STATUS_TONE } from "./documentStatus";

defineProps<{ row: StockDocument }>();

const emit = defineEmits<{ open: [] }>();
</script>
