<template>
  <div class="relative flex min-h-16 flex-col items-stretch justify-center gap-1 p-1">
    <button
      v-if="state.selectable"
      type="button"
      class="flex min-h-11 w-full items-center justify-center gap-1 rounded-lg border text-xs font-semibold transition-colors"
      :class="selected ? 'border-primary bg-primary/10 text-primary ring-2 ring-primary' : 'border-dashed bg-white text-muted-foreground hover:bg-muted'"
      :aria-pressed="selected"
      @click="emit('toggle')"
    >
      <Check v-if="selected" class="size-4" />
      <span v-else-if="state.kind === 'rejected'" class="text-rose-700">{{ $t("attendance.register.cell.rejected") }}</span>
      <Plus v-else class="size-4" />
    </button>
    <div v-else-if="state.kind !== 'empty'" class="flex flex-col items-center gap-1">
      <RegisterCellBadge :kind="state.kind" />
      <button
        v-if="state.kind === 'pending' && state.requestId"
        type="button"
        class="min-h-9 rounded-md px-2 text-xs text-muted-foreground underline"
        @click="emit('cancel', state.requestId)"
      >
        {{ $t("attendance.register.cancel") }}
      </button>
    </div>
    <div v-else class="min-h-11 rounded-lg border border-dashed bg-muted/30" />
    <TriangleAlert v-if="state.unavailable && state.kind !== 'approved'" class="absolute right-1 top-1 size-3.5 text-amber-600" :title="$t('attendance.register.unavailableHint')" />
    <p v-if="state.note" class="text-center text-[11px] leading-tight text-muted-foreground">{{ state.note }}</p>
  </div>
</template>

<script lang="ts" setup>
import { Check, Plus, TriangleAlert } from "lucide-vue-next";
import RegisterCellBadge from "./RegisterCellBadge.vue";
import type { CellState } from "./registerGrid";

defineProps<{ state: CellState; selected: boolean }>();
const emit = defineEmits<{ toggle: []; cancel: [id: string] }>();
</script>
