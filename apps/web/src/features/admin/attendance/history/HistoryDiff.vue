<template>
  <table v-if="fields.length" class="w-full text-xs">
    <tbody>
      <tr v-for="field in fields" :key="field" class="border-t first:border-t-0">
        <th class="w-1/4 py-1 pr-2 text-left font-medium text-muted-foreground">{{ label(field) }}</th>
        <td v-if="row.action === 'update'" class="py-1">
          <span class="text-red-700 line-through">{{ shown(before, field) }}</span>
          <span class="mx-1 text-muted-foreground">→</span>
          <span class="font-semibold text-emerald-700">{{ shown(after, field) }}</span>
        </td>
        <td v-else class="py-1 font-medium">{{ shown(row.action === 'delete' ? before : after, field) }}</td>
      </tr>
    </tbody>
  </table>
  <p v-else class="text-xs text-muted-foreground">{{ $t("attendance.history.noDetails") }}</p>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import { visibleFields } from "@bongcun/core/attendance";
import type { HistoryRow } from "@bongcun/core/attendance";
import { formatHistoryValue } from "./historyLabels";

const props = defineProps<{ row: HistoryRow }>();
const { t, te } = useI18n();

const asObject = (value: HistoryRow["before"]): Record<string, unknown> => (value && !Array.isArray(value) ? value : {});
const before = computed(() => asObject(props.row.before));
const after = computed(() => asObject(props.row.after));
const fields = computed(() => (Array.isArray(props.row.before) || Array.isArray(props.row.after) ? [] : visibleFields(props.row)));

const label = (field: string) => (te(`attendance.history.fields.${field}`) ? t(`attendance.history.fields.${field}`) : field);
const shown = (data: Record<string, unknown>, field: string) => formatHistoryValue(data[field]);
</script>
