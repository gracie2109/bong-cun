<template>
  <li class="flex flex-wrap items-center gap-3 px-4 py-3" :class="!template.isActive && 'opacity-60'">
    <ShiftChip :color="template.color" :name="template.name" class="min-w-32" />
    <span class="text-sm tabular-nums">
      {{ template.startTime }} – {{ template.endTime }}
      <span v-if="template.overnight" class="ml-1 rounded bg-muted px-1.5 py-0.5 text-[11px] font-semibold text-muted-foreground">
        {{ $t("attendance.templates.overnight") }}
      </span>
    </span>
    <span class="text-xs text-muted-foreground">{{ $t("attendance.templates.breakShort", { n: template.breakMinutes }) }}</span>
    <span class="text-xs text-muted-foreground">{{ formatMinutes(netMinutes) }}</span>
    <div v-if="canEdit" class="ml-auto flex gap-1">
      <Button size="sm" variant="ghost" @click="emit('edit')">{{ $t("petCare.common.edit") }}</Button>
      <Button size="sm" variant="ghost" @click="emit('toggle')">
        {{ template.isActive ? $t("petCare.common.archive") : $t("petCare.common.restore") }}
      </Button>
    </div>
  </li>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Button } from "@/components/ui/button";
import ShiftChip from "@/features/admin/attendance/shared/ShiftChip.vue";
import { formatMinutes, shiftLengthMinutes } from "@bongcun/core/attendance";
import type { ShiftTemplate } from "@bongcun/core/attendance";

const props = defineProps<{ template: ShiftTemplate; canEdit: boolean }>();
const emit = defineEmits<{ edit: []; toggle: [] }>();

/** Paid length: the shift minus its break. */
const netMinutes = computed(() => shiftLengthMinutes(props.template.startTime, props.template.endTime) - props.template.breakMinutes);
</script>
