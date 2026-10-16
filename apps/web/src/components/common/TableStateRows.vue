<template>
  <template v-if="pending">
    <tr v-for="i in skeletonRows" :key="i" class="border-t">
      <td :colspan="colspan" class="px-4 py-3"><Skeleton :class="skeletonClass" /></td>
    </tr>
  </template>
  <tr v-else-if="empty" data-table-empty>
    <td :colspan="colspan" class="px-4 py-12 text-center align-middle text-muted-foreground">
      <Inbox class="mx-auto mb-2 size-8 text-primary/60" />
      <template v-if="filtered">
        {{ $t("common.searchView.noResults") }}
        <div class="mt-3">
          <Button type="button" variant="outline" size="sm" @click="emit('clear')">{{ $t("common.searchView.clearFilters") }}</Button>
        </div>
      </template>
      <template v-else>{{ emptyText }}</template>
    </td>
  </tr>
</template>

<script lang="ts" setup>
import { Inbox } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";

/** Rows for a table body that has nothing to list yet: placeholders while loading, a message when empty. */
const emit = defineEmits<{ (event: "clear"): void }>();
withDefaults(
  defineProps<{
    /** Columns of the table, so the row spans it. */
    colspan: number;
    pending: boolean;
    empty: boolean;
    emptyText: string;
    /** The list is empty because of the search or filters: say so and offer to clear them. */
    filtered?: boolean;
    skeletonRows?: number;
    skeletonClass?: string;
  }>(),
  { skeletonRows: 5, skeletonClass: "h-8 w-full" }
);
</script>
