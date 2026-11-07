<template>
  <li class="flex items-center justify-between gap-3 px-4 py-3">
    <div class="min-w-0">
      <p class="truncate text-sm font-semibold">{{ row.name }}</p>
      <p class="text-xs" :class="STATE_CLASS[row.state]">{{ $t(`attendance.publish.missing.state.${row.state}`, { count: row.requestCount }) }}</p>
    </div>
    <Button v-if="canAssign && row.state === 'missing'" size="sm" variant="outline" class="min-h-9 shrink-0" :disabled="busy" @click="emit('likeLastWeek')">
      {{ $t("attendance.publish.missing.likeLastWeek") }}
    </Button>
  </li>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import type { RegistrationStatusRow } from "@bongcun/core/attendance";

defineProps<{ row: RegistrationStatusRow; canAssign: boolean; busy: boolean }>();
const emit = defineEmits<{ likeLastWeek: [] }>();

const STATE_CLASS = {
  missing: "text-rose-700",
  submitted: "text-emerald-700",
  declared_none: "text-sky-700",
  exempt: "text-muted-foreground",
  manager: "text-muted-foreground",
} as const;
</script>
