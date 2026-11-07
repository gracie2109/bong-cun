<template>
  <span class="inline-flex items-center gap-1 rounded-md px-1.5 py-0.5 text-xs font-semibold" :class="CELL_CLASS[kind]">
    <component :is="ICON[kind]" class="size-3.5" aria-hidden="true" />
    {{ $t(`attendance.register.cell.${kind}`) }}
  </span>
</template>

<script lang="ts" setup>
import { Ban, CalendarOff, Check, CircleX, Clock } from "lucide-vue-next";
import type { CellKind } from "./registerGrid";

defineProps<{ kind: Exclude<CellKind, "empty"> }>();

const ICON = { pending: Clock, approved: Check, rejected: CircleX, onRoster: Check, leave: CalendarOff, overlap: Ban } as const;
const CELL_CLASS = {
  pending: "bg-amber-50 text-amber-800",
  approved: "bg-emerald-50 text-emerald-800",
  rejected: "bg-rose-50 text-rose-800",
  onRoster: "bg-teal-50 text-teal-800",
  leave: "bg-sky-50 text-sky-800",
  overlap: "bg-muted text-muted-foreground",
} as const;
</script>
