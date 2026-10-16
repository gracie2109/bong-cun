<template>
  <div class="flex min-h-0 flex-1 flex-col gap-3">
    <div v-if="errorCount > 0" class="flex flex-wrap items-center justify-between gap-3">
      <label class="flex items-center gap-2 text-sm text-muted-foreground">
        <Switch v-model:checked="onlyErrors" />
        {{ $t("dataIo.import.onlyErrors") }}
      </label>
      <Button v-if="canDownloadErrors" variant="outline" size="sm" @click="emit('downloadErrors')">
        <Download class="mr-2 size-4" />
        {{ $t("dataIo.import.downloadErrors") }}
      </Button>
    </div>
    <PagedTableCard
      class="min-h-0 flex-1"
      v-model:page="page"
      v-model:page-size="pageSize"
      :page-count="pageCount"
      :count="visible.length"
      :total="shown.length"
      :scroll-x="700"
    >
      <table class="w-full text-sm">
        <thead>
          <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
            <th class="px-4 py-3 font-semibold">{{ $t("dataIo.import.col.row") }}</th>
            <th v-for="column in columns" :key="column.label" class="px-4 py-3 font-semibold" :class="column.right ? 'text-right' : ''">
              {{ column.label }}
            </th>
            <th class="px-4 py-3 font-semibold">{{ $t("dataIo.import.col.result") }}</th>
          </tr>
        </thead>
        <tbody>
          <TableStateRows :colspan="columns.length + 2" :pending="false" :empty="shown.length === 0" :empty-text="$t('dataIo.import.empty')" />
          <tr v-for="item in visible" :key="item.rowNo" class="border-t align-top" :class="item.errors.length ? 'bg-destructive/5' : ''">
            <td class="px-4 py-2 text-muted-foreground">{{ item.rowNo }}</td>
            <td v-for="column in columns" :key="column.label" class="px-4 py-2" :class="column.right ? 'text-right' : ''">
              {{ column.cell(item.row) }}
            </td>
            <td class="px-4 py-2">
              <ul v-if="item.errors.length" class="space-y-0.5 text-destructive">
                <li v-for="note in item.errors" :key="note">{{ note }}</li>
              </ul>
              <span v-else :class="item.action === 'create' ? 'text-primary' : 'text-muted-foreground'">
                {{ $t(`dataIo.import.action.${item.action}`) }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </PagedTableCard>
  </div>
</template>

<script lang="ts" setup generic="R">
import { computed, ref, watch } from "vue";
import { Download } from "lucide-vue-next";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import type { PreviewColumn, PreviewRow } from "@/composables/useTableImport";

const props = defineProps<{ rows: PreviewRow<R>[]; columns: PreviewColumn<R>[]; canDownloadErrors?: boolean }>();
const emit = defineEmits<{ downloadErrors: [] }>();

const onlyErrors = ref(false);
const page = ref(1);
const pageSize = ref(20);

const errorCount = computed(() => props.rows.filter((item) => item.errors.length > 0).length);
const shown = computed(() => (onlyErrors.value ? props.rows.filter((item) => item.errors.length > 0) : props.rows));
const pageCount = computed(() => Math.max(1, Math.ceil(shown.value.length / pageSize.value)));
const visible = computed(() => shown.value.slice((page.value - 1) * pageSize.value, page.value * pageSize.value));

watch([onlyErrors, () => props.rows], () => (page.value = 1));
</script>
