<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <ClipboardCheck class="size-4 text-primary" />
      {{ $t("attendance.today.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <AttendanceNav />
        <BranchPicker :model-value="branchId" :branches="branches" @update:model-value="selectBranch" />
      </div>

      <div class="flex flex-wrap items-center gap-2">
        <Button type="button" variant="outline" size="icon" class="size-11" :aria-label="$t('attendance.today.previousDay')" @click="previous"><ChevronLeft class="size-4" /></Button>
        <span class="min-w-28 text-center font-semibold">{{ dayMonth(date) }}/{{ date.slice(0, 4) }}</span>
        <Button type="button" variant="outline" size="icon" class="size-11" :aria-label="$t('attendance.today.nextDay')" @click="next"><ChevronRight class="size-4" /></Button>
        <Button v-if="!isToday" type="button" variant="outline" class="min-h-11" @click="today">{{ $t("attendance.today.backToToday") }}</Button>
        <dl class="ml-auto flex flex-wrap gap-2 text-sm">
          <div v-for="item in chips" :key="item.key" class="rounded-lg border bg-white px-3 py-1.5">
            <dt class="inline text-muted-foreground">{{ $t(`attendance.today.summary.${item.key}`) }}: </dt>
            <dd class="inline font-semibold">{{ item.value }}</dd>
          </div>
        </dl>
      </div>

      <div class="min-h-0 flex-1 space-y-4 overflow-y-auto">
        <ReviewQueue :items="board?.review ?? []" :can-edit="canUpdate" @edit="(id) => edit.openForEntry(id, board?.rows ?? [])" @reviewed="edit.markReviewed" />
        <ul class="grid gap-3 lg:grid-cols-2">
          <TodayStaffRow v-for="line in lines" :key="line.staff.userId" :line="line" :can-edit="canUpdate" @edit="edit.openFor" />
        </ul>
        <p v-if="!lines.length && !query.isPending.value" class="rounded-lg border border-dashed bg-white px-4 py-3 text-sm text-muted-foreground">
          {{ $t("attendance.today.empty") }}
        </p>
      </div>
    </div>
  </ContentWrap>

  <EntryEditDialog
    v-model:open="edit.open.value"
    v-model:draft="edit.draft.value"
    :row="edit.row.value"
    :is-new="edit.isNew.value"
    :busy="edit.busy.value"
    :error="edit.error.value"
    :can-delete="canDelete"
    @submit="edit.submit"
    @remove="edit.removeEntry"
  />
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { ChevronLeft, ChevronRight, ClipboardCheck } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { useAuthStore } from "@/stores";
import { ContentWrap, Header } from "@/features/admin/components";
import { BranchPicker } from "@/features/admin/pos";
import { dayMonth } from "@/features/admin/attendance/shared/attendanceFormat";
import AttendanceNav from "../AttendanceNav.vue";
import EntryEditDialog from "./EntryEditDialog.vue";
import ReviewQueue from "./ReviewQueue.vue";
import TodayStaffRow from "./TodayStaffRow.vue";
import { useEntryEdit } from "./useEntryEdit";
import { useTodayBoard } from "./useAttendanceToday";

const auth = useAuthStore();
const { branches, branchId, selectBranch } = useCurrentBranch();
const canUpdate = computed(() => auth.can("attendance", "UPDATE"));
const canDelete = computed(() => auth.can("attendance", "DELETE"));

const { date, query, board, lines, summary, isToday, previous, next, today } = useTodayBoard(branchId);
const edit = useEntryEdit(branchId);

const chips = computed(() => [
  { key: "working", value: summary.value.working },
  { key: "notIn", value: summary.value.notIn },
  { key: "upcoming", value: summary.value.upcoming },
  { key: "done", value: summary.value.done },
  { key: "leave", value: summary.value.leave },
]);
</script>
