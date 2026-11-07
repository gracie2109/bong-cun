<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <CalendarRange class="size-4 text-primary" />
      {{ $t("attendance.roster.title") }}
    </h1>
  </Header>

  <ContentWrap fill wide>
    <div class="flex min-h-0 flex-1 flex-col gap-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <AttendanceNav />
        <BranchPicker :model-value="branchId" :branches="branches" @update:model-value="selectBranch" />
      </div>

      <RosterToolbar
        :monday="monday"
        :label="label"
        :is-this-week="isThisWeek"
        :is-past-week="isPastWeek"
        :can-create="canCreate"
        :pending-count="pendingCount"
        @previous="previous"
        @next="next"
        @select="select"
        @today="today"
        @copy="copyOpen = true"
      >
        <template #publish>
          <MissingRegistrationButton :branch-id="branchId" :monday="monday" :week="week" :can-view="canCreate" :can-assign="canCreate" />
          <PublishWeekButton :branch-id="branchId" :monday="monday" :week="week" :shifts="shiftCount" :can-publish="canCreate" />
        </template>
      </RosterToolbar>

      <p v-if="templates.length === 0 && !query.isPending.value" class="rounded-lg border border-dashed bg-white px-4 py-3 text-sm text-muted-foreground">
        {{ $t("attendance.roster.noTemplates") }}
        <router-link :to="{ name: 'attendanceSettings' }" class="font-semibold text-primary underline">{{ $t("attendance.nav.settings") }}</router-link>
      </p>

      <RosterGrid
        :rows="rows"
        :days="days"
        :can-create="canCreate"
        :can-open="canUpdate"
        :can-decide="canCreate"
        @add="dialog.add"
        @edit="dialog.edit"
        @decide="openDecide"
        @availability="openAvailability"
      />
    </div>
  </ContentWrap>

  <AssignShiftDialog
    v-model:open="dialog.open.value"
    :branch-id="branchId"
    :staff="dialog.staff.value"
    :date="dialog.date.value"
    :assignment="dialog.assignment.value"
    :templates="templates"
    :can-delete="canDelete"
    :availability="availability"
    :published="isPublished"
  />
  <CopyWeekDialog v-model:open="copyOpen" :branch-id="branchId" :to-monday="monday" :published="isPublished" />
  <DecideRequestsDialog v-model:open="decideOpen" :ids="decideIds" :description="decideDescription" :names="decideNames" />
  <AvailabilityDialog v-model:open="availabilityOpen" :user-id="availabilityUser?.userId" :title="availabilityUser?.name" />
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { CalendarRange } from "lucide-vue-next";
import { useWeekStatus } from "@/features/admin/attendance/queries";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { useAuthStore } from "@/stores";
import { ContentWrap, Header } from "@/features/admin/components";
import { BranchPicker } from "@/features/admin/pos";
import AttendanceNav from "../AttendanceNav.vue";
import AvailabilityDialog from "../availability/AvailabilityDialog.vue";
import DecideRequestsDialog from "../requests/DecideRequestsDialog.vue";
import MissingRegistrationButton from "../publish/MissingRegistrationButton.vue";
import PublishWeekButton from "../publish/PublishWeekButton.vue";
import AssignShiftDialog from "./AssignShiftDialog.vue";
import CopyWeekDialog from "./CopyWeekDialog.vue";
import RosterGrid from "./RosterGrid.vue";
import RosterToolbar from "./RosterToolbar.vue";
import { useAssignDialog } from "./useAssignDialog";
import { useRoster } from "./useRoster";
import { useRosterReview } from "./useRosterReview";
import { useRosterWeek } from "./useRosterWeek";

const auth = useAuthStore();
const { branches, branchId, selectBranch } = useCurrentBranch();
const canCreate = computed(() => auth.can("attendance", "CREATE"));
const canUpdate = computed(() => auth.can("attendance", "UPDATE") || canCreate.value);
const canDelete = computed(() => auth.can("attendance", "DELETE"));

const { monday, days, sunday, isThisWeek, isPastWeek, previous, next, select, today } = useRosterWeek();
const { query, roster, rows, templates, availability, requests } = useRoster(branchId, monday, sunday, days);
const weekQuery = useWeekStatus(branchId, monday);
const week = computed(() => weekQuery.data.value);
const shiftCount = computed(() => roster.value.assignments.length);
const isPublished = computed(() => !!week.value?.requirePublish && week.value.status === "published");
const pendingCount = computed(() => requests.value.filter((request) => !request.expired).length);
const label = computed(() => `${monday.value.slice(8)}/${monday.value.slice(5, 7)} – ${sunday.value.slice(8)}/${sunday.value.slice(5, 7)}/${sunday.value.slice(0, 4)}`);

const dialog = useAssignDialog();
const { decideOpen, decideIds, decideDescription, decideNames, openDecide, availabilityOpen, availabilityUser, openAvailability } = useRosterReview(rows);
const copyOpen = ref(false);
</script>
