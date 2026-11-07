<template>
  <AppDialog :open="open" :title="$t('attendance.register.resultTitle')" :ok-text="$t('attendance.register.close')" hide-cancel @update:open="emit('update:open', $event)" @ok="emit('update:open', false)">
    <div v-if="result" class="space-y-3 text-sm">
      <p>{{ $t("attendance.register.resultSummary", { created: result.created.length, skipped: result.skipped.length }) }}</p>
      <ul v-if="warnings.length" class="space-y-1 rounded-lg border border-amber-200 bg-amber-50 p-3 text-amber-900">
        <li v-for="item in warnings" :key="item.id">{{ shortDate(item.workDate) }}: {{ $t(`attendance.register.warning.${item.warning}`) }}</li>
      </ul>
      <ul v-if="result.skipped.length" class="space-y-1 rounded-lg border p-3">
        <li v-for="(item, index) in result.skipped" :key="index">
          {{ item.workDate ? shortDate(item.workDate) : "" }} {{ templateName(item.templateId) }}:
          {{ $te(`attendance.errors.${item.hint}`) ? $t(`attendance.errors.${item.hint}`) : item.hint }}
        </li>
      </ul>
    </div>
  </AppDialog>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import type { RegistrationTemplate, SubmitResult } from "@bongcun/core/attendance";

const props = defineProps<{ open: boolean; result: SubmitResult | null; templates: RegistrationTemplate[] }>();
const emit = defineEmits<{ "update:open": [boolean] }>();

const warnings = computed(() => props.result?.created.filter((item) => item.warning) ?? []);
const shortDate = (date: string) => `${date.slice(8)}/${date.slice(5, 7)}`;
const templateName = (id: string | null) => props.templates.find((t) => t.id === id)?.name ?? "";
</script>
