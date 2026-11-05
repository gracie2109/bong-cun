<template>
  <section class="rounded-xl border bg-white p-4 xl:col-span-2">
    <header class="mb-3 flex flex-wrap items-center justify-between gap-2">
      <h2 class="font-semibold">{{ $t("attendance.leave.myTitle", { year: data?.year ?? "" }) }}</h2>
      <Button type="button" class="min-h-11" :disabled="!branches.length" @click="open = true">
        <Plus class="mr-1 size-4" />
        {{ $t("attendance.leave.request") }}
      </Button>
    </header>

    <p v-if="data" class="mb-3 rounded-lg border bg-muted/30 px-3 py-2 text-sm">
      {{ $t("attendance.leave.balance", { remaining: data.balance.remaining, allowance: data.balance.allowance, pending: data.balance.pending }) }}
    </p>

    <p v-if="!data?.requests.length" class="text-sm text-muted-foreground">{{ $t("attendance.leave.noneMine") }}</p>
    <ul v-else class="space-y-2">
      <LeaveRow v-for="request in data.requests" :key="request.id" :request="request">
        <template #actions>
          <Button v-if="canCancel(request)" type="button" size="sm" variant="ghost" class="min-h-9" :disabled="cancelling" @click="cancel.mutate(request.id)">
            {{ $t("attendance.leave.cancel") }}
          </Button>
        </template>
      </LeaveRow>
    </ul>
  </section>

  <LeaveRequestDialog v-model:open="open" :branches="branches" :default-branch-id="branches[0]?.id" />
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { Plus } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { useCancelLeave, useClockStatus, useMyLeave } from "@/features/admin/attendance/queries";
import { todayInVietnam } from "@/lib/businessDate";
import type { LeaveRequest } from "@bongcun/core/attendance";
import LeaveRequestDialog from "../leave/LeaveRequestDialog.vue";
import LeaveRow from "../leave/LeaveRow.vue";

const query = useMyLeave();
const data = computed(() => query.data.value);
// The branches the person works at are the ones that can approve their leave.
const status = useClockStatus();
const branches = computed(() => (status.data.value?.branches ?? []).map((branch) => ({ id: branch.id, name: branch.name })));

const open = ref(false);
const cancel = useCancelLeave();
const cancelling = cancel.isPending;
const today = todayInVietnam();
const canCancel = (request: LeaveRequest) => request.status === "pending" || (request.status === "approved" && request.fromDate > today);
</script>
