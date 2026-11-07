<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <CalendarPlus class="size-4 text-primary" />
      {{ $t("attendance.register.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <AttendanceNav />
        <BranchPicker :model-value="branchId" :branches="branches" @update:model-value="selectBranch" />
      </div>

      <RegisterToolbar :label="week.label.value" :is-first-week="week.isFirstWeek.value" @previous="week.previous" @next="week.next" @reset="week.reset" />

      <p v-if="!branches.length" class="rounded-lg border border-dashed bg-white px-4 py-3 text-sm text-muted-foreground">{{ $t("attendance.register.noBranch") }}</p>

      <div v-if="board" class="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto">
        <RegisterWindowNotice :board="board" :quota="quota" />
        <RegisterWeekStateBanner :board="board" :withdrawing="withdrawing" @declare="declareNone" @withdraw="withdrawNone" />
        <p v-if="!board.templates.length" class="rounded-lg border border-dashed bg-white px-4 py-3 text-sm text-muted-foreground">{{ $t("attendance.register.noTemplates") }}</p>
        <component :is="narrow ? RegisterDayList : RegisterGrid" v-else :board="board" :selection="selection" @cancel="cancel" />
        <RegisterSubmitBar v-if="board.window.open && staffCanEditWeek(board.week)" v-model:note="note" :count="selection.count.value" :sending="sending" :over-quota="overQuota" @send="send" @clear="selection.clear" />
      </div>
      <p v-else-if="query.isPending.value && branchId" class="text-sm text-muted-foreground">…</p>
    </div>
  </ContentWrap>

  <RegisterResultDialog v-model:open="resultOpen" :result="result" :templates="board?.templates ?? []" />
  <ConfirmReasonDialog :confirm="confirm" />
</template>

<script lang="ts" setup>
import { CalendarPlus } from "lucide-vue-next";
import { useMediaQuery } from "@vueuse/core";
import { ContentWrap, Header } from "@/features/admin/components";
import { BranchPicker } from "@/features/admin/pos";
import AttendanceNav from "../AttendanceNav.vue";
import RegisterDayList from "./RegisterDayList.vue";
import RegisterGrid from "./RegisterGrid.vue";
import ConfirmReasonDialog from "@/components/common/ConfirmReasonDialog.vue";
import RegisterResultDialog from "./RegisterResultDialog.vue";
import RegisterSubmitBar from "./RegisterSubmitBar.vue";
import RegisterToolbar from "./RegisterToolbar.vue";
import RegisterWeekStateBanner from "./RegisterWeekStateBanner.vue";
import RegisterWindowNotice from "./RegisterWindowNotice.vue";
import { staffCanEditWeek } from "@bongcun/core/attendance";
import { useRegisterPage } from "./useRegisterPage";

const narrow = useMediaQuery("(max-width: 767px)");
const { branches, branchId, selectBranch, week, query, board, selection, note, quota, overQuota, sending, cancel, confirm, send, declareNone, withdrawNone, withdrawing, result, resultOpen } = useRegisterPage();
</script>
