<template>
  <div class="flex min-h-0 flex-1 flex-col gap-3">
    <label v-if="errorCount > 0" class="flex items-center gap-2 text-sm text-muted-foreground">
      <Switch v-model:checked="onlyErrors" />
      {{ $t("productImport.onlyErrors") }}
    </label>
    <PagedTableCard
      class="min-h-0 flex-1"
      v-model:page="page"
      v-model:page-size="pageSize"
      :page-count="pageCount"
      :count="visible.length"
      :total="shown.length"
      :scroll-x="900"
    >
      <table class="w-full text-sm">
        <thead>
          <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
            <th class="px-4 py-3 font-semibold">{{ $t("productImport.col.row") }}</th>
            <th class="px-4 py-3 font-semibold">{{ $t("productImport.col.group") }}</th>
            <th class="px-4 py-3 font-semibold">{{ $t("productImport.col.sku") }}</th>
            <th class="px-4 py-3 text-right font-semibold">{{ $t("productImport.col.price") }}</th>
            <th class="px-4 py-3 font-semibold">{{ $t("productImport.col.result") }}</th>
          </tr>
        </thead>
        <tbody>
          <TableStateRows :colspan="5" :pending="false" :empty="shown.length === 0" :empty-text="$t('productImport.empty')" />
          <tr v-for="item in visible" :key="item.row.row" class="border-t align-top" :class="item.errors.length ? 'bg-destructive/5' : ''">
            <td class="px-4 py-2 text-muted-foreground">{{ item.row.row }}</td>
            <td class="px-4 py-2">{{ item.row.group }}</td>
            <td class="px-4 py-2 font-mono text-xs">{{ item.row.sku }}</td>
            <td class="px-4 py-2 text-right">{{ item.row.price ?? "" }}</td>
            <td class="px-4 py-2">
              <ul v-if="item.errors.length" class="space-y-0.5 text-destructive">
                <li v-for="note in item.errors" :key="note">{{ note }}</li>
              </ul>
              <span v-else :class="item.action === 'create' ? 'text-primary' : 'text-muted-foreground'">
                {{ $t(`productImport.action.${item.action}`) }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </PagedTableCard>
  </div>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import { Switch } from "@/components/ui/switch";
import type { PreviewRow } from "./useProductImport";

const props = defineProps<{ rows: PreviewRow[] }>();

const onlyErrors = ref(false);
const page = ref(1);
const pageSize = ref(20);

const errorCount = computed(() => props.rows.filter((item) => item.errors.length > 0).length);
const shown = computed(() => (onlyErrors.value ? props.rows.filter((item) => item.errors.length > 0) : props.rows));
const pageCount = computed(() => Math.max(1, Math.ceil(shown.value.length / pageSize.value)));
const visible = computed(() => shown.value.slice((page.value - 1) * pageSize.value, page.value * pageSize.value));

watch([onlyErrors, () => props.rows], () => (page.value = 1));
</script>
