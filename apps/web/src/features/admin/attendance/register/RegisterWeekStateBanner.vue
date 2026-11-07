<template>
  <div v-if="board.week.requirePublish" class="space-y-2">
    <p v-if="!staffCanEditWeek(board.week)" class="rounded-lg border border-sky-200 bg-sky-50 px-4 py-3 text-sm text-sky-900">
      {{ $t("attendance.register.weekPublished") }}
    </p>
    <div v-else-if="board.submission" class="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-sky-200 bg-sky-50 px-4 py-3 text-sm text-sky-900">
      <span>
        {{ $t("attendance.register.declared") }}
        <span v-if="board.submission.reason">· {{ board.submission.reason }}</span>
      </span>
      <Button size="sm" variant="outline" class="min-h-9 bg-white" :disabled="withdrawing" @click="emit('withdraw')">{{ $t("attendance.register.withdrawDeclared") }}</Button>
    </div>
    <DeclareNoShiftsButton v-else-if="canDeclare" @declare="emit('declare', $event)" />
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Button } from "@/components/ui/button";
import { staffCanEditWeek } from "@bongcun/core/attendance";
import type { RegistrationBoard } from "@bongcun/core/attendance";
import DeclareNoShiftsButton from "./DeclareNoShiftsButton.vue";

const props = defineProps<{ board: RegistrationBoard; withdrawing: boolean }>();
const emit = defineEmits<{ declare: [reason: string | null]; withdraw: [] }>();

// Declaring "no shifts" only makes sense while nothing is asked for and the window is open.
const canDeclare = computed(
  () => props.board.window.open && !props.board.requests.some((request) => request.status === "pending" || request.status === "submitted")
);
</script>
