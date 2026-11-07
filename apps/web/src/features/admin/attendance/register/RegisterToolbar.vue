<template>
  <div class="flex flex-wrap items-center gap-2">
    <div class="flex items-center rounded-xl border bg-white p-1">
      <Button size="icon" variant="ghost" class="size-10" :aria-label="$t('attendance.roster.previousWeek')" @click="emit('previous')">
        <ChevronLeft class="size-4" />
      </Button>
      <span class="min-w-44 px-2 text-center text-sm font-semibold tabular-nums">{{ label }}</span>
      <Button size="icon" variant="ghost" class="size-10" :aria-label="$t('attendance.roster.nextWeek')" @click="emit('next')">
        <ChevronRight class="size-4" />
      </Button>
    </div>
    <Button variant="outline" :disabled="isFirstWeek" @click="emit('reset')">{{ $t("attendance.register.nextWeek") }}</Button>
  </div>
</template>

<script lang="ts" setup>
import { ChevronLeft, ChevronRight } from "lucide-vue-next";
import { Button } from "@/components/ui/button";

defineProps<{ label: string; isFirstWeek: boolean }>();
const emit = defineEmits<{ previous: []; next: []; reset: [] }>();
</script>
