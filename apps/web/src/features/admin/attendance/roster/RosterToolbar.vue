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
    <Button variant="outline" :disabled="isThisWeek" @click="emit('today')">{{ $t("attendance.roster.thisWeek") }}</Button>
    <div class="ml-auto flex flex-wrap items-center gap-2">
      <slot name="publish" />
      <RosterPendingButton :count="pendingCount" />
    </div>
    <Button v-if="canCreate" variant="outline" @click="emit('copy')">
      <Copy class="mr-1 size-4" />
      {{ $t("attendance.roster.copyWeek") }}
    </Button>
  </div>
</template>

<script lang="ts" setup>
import { ChevronLeft, ChevronRight, Copy } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import RosterPendingButton from "./RosterPendingButton.vue";

defineProps<{ label: string; isThisWeek: boolean; canCreate: boolean; pendingCount: number }>();
const emit = defineEmits<{ previous: []; next: []; today: []; copy: [] }>();
</script>
