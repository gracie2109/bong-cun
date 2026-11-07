<template>
  <div class="space-y-2">
    <p class="rounded-lg border px-4 py-3 text-sm" :class="board.window.open ? 'border-emerald-200 bg-emerald-50 text-emerald-900' : 'bg-white text-muted-foreground'">
      {{ message }}
    </p>
    <p v-if="board.rules.staffNote" class="rounded-lg border bg-white px-4 py-3 text-sm">{{ board.rules.staffNote }}</p>
    <p v-if="board.rules.maxShiftsPerWeek !== null" class="text-xs text-muted-foreground">
      {{ $t("attendance.register.limit", { max: board.rules.maxShiftsPerWeek, left: quota ?? 0 }) }}
    </p>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import type { RegistrationBoard } from "@bongcun/core/attendance";
import { closesLabel } from "./registerFormat";

const props = defineProps<{ board: RegistrationBoard; quota: number | null }>();
const { t } = useI18n();
const message = computed(() => {
  const { window } = props.board;
  return window.open
    ? t("attendance.register.open", { deadline: closesLabel(window.closesAt) })
    : t(`attendance.register.closedReason.${window.reason ?? "closed"}`, { deadline: closesLabel(window.closesAt) });
});
</script>
