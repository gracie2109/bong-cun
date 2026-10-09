<template>
  <template v-if="pending">
    <tr v-for="i in skeletonRows" :key="i" class="border-t">
      <td :colspan="colspan" class="px-4 py-3"><Skeleton :class="skeletonClass" /></td>
    </tr>
  </template>
  <tr v-else-if="empty" data-table-empty>
    <td :colspan="colspan" class="px-4 py-12 text-center align-middle text-muted-foreground">
      <Inbox class="mx-auto mb-2 size-8 text-primary/60" />
      {{ emptyText }}
    </td>
  </tr>
</template>

<script lang="ts" setup>
import { Inbox } from "lucide-vue-next";
import { Skeleton } from "@/components/ui/skeleton";

/** Rows for a table body that has nothing to list yet: placeholders while loading, a message when empty. */
withDefaults(
  defineProps<{
    /** Columns of the table, so the row spans it. */
    colspan: number;
    pending: boolean;
    empty: boolean;
    emptyText: string;
    skeletonRows?: number;
    skeletonClass?: string;
  }>(),
  { skeletonRows: 5, skeletonClass: "h-8 w-full" }
);
</script>
