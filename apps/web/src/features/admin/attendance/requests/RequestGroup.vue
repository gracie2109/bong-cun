<template>
  <section class="rounded-xl border bg-white">
    <header class="flex flex-wrap items-center gap-x-3 gap-y-2 border-b bg-muted/30 px-3 py-2">
      <input
        v-if="selectable && group.pendingIds.length"
        type="checkbox"
        class="size-5 shrink-0"
        :checked="allTicked"
        :aria-label="$t('attendance.requests.group.selectGroup')"
        @change="emit('toggleGroup')"
      />
      <p class="font-semibold tabular-nums">{{ $t(`attendance.weekday.${isoWeekday(group.workDate)}`) }} {{ dayMonth(group.workDate) }}</p>
      <ShiftChip :color="group.color" :name="group.name" />
      <span class="text-sm tabular-nums text-muted-foreground">{{ timeOf(group.startAt) }}–{{ timeOf(group.endAt) }}</span>
      <span class="ml-auto rounded-full bg-primary/10 px-2.5 py-0.5 text-xs font-semibold text-primary">
        {{ $t("attendance.requests.group.people", { n: group.requests.length }) }}
        <template v-if="group.pendingIds.length !== group.requests.length"> · {{ $t("attendance.requests.group.pending", { n: group.pendingIds.length }) }}</template>
      </span>
    </header>
    <ul class="divide-y">
      <RequestRow
        v-for="(request, index) in visible"
        :key="request.id"
        :request="request"
        :position="index + 1"
        grouped
        :selectable="selectable && canTick(request)"
        :selected="isSelected(request.id)"
        @toggle="emit('toggle', request.id)"
      >
        <template #actions>
          <slot name="actions" :request="request" />
        </template>
      </RequestRow>
    </ul>
    <button v-if="hiddenCount > 0 || expanded" type="button" class="w-full border-t px-3 py-2 text-sm font-semibold text-primary hover:bg-muted/40" @click="expanded = !expanded">
      {{ expanded ? $t("attendance.requests.group.showLess") : $t("attendance.requests.group.showMore", { n: hiddenCount }) }}
    </button>
  </section>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { dayMonth, timeOf } from "@/features/admin/attendance/shared/attendanceFormat";
import ShiftChip from "@/features/admin/attendance/shared/ShiftChip.vue";
import { isoWeekday } from "@bongcun/core/attendance";
import type { RequestGroup } from "./groupRequests";
import RequestRow from "./RequestRow.vue";
import { canTick } from "./useRequestSelection";

/** Past this many people the group folds, so a popular shift does not push the rest of the list away. */
const FOLD_AFTER = 5;

const props = defineProps<{ group: RequestGroup; selectable: boolean; isSelected: (id: string) => boolean; allTicked: boolean }>();
const emit = defineEmits<{ toggle: [id: string]; toggleGroup: [] }>();

const expanded = ref(false);
const visible = computed(() => (expanded.value ? props.group.requests : props.group.requests.slice(0, FOLD_AFTER)));
const hiddenCount = computed(() => Math.max(0, props.group.requests.length - FOLD_AFTER));
</script>
