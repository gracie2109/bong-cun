<template>
  <router-link
    v-if="visible"
    :to="{ name: 'medicalQueue' }"
    class="block rounded-xl border bg-white p-4 transition-colors hover:border-primary hover:bg-primary/5"
  >
    <div class="flex flex-wrap items-center justify-between gap-2">
      <h3 class="flex items-center gap-2 text-sm font-semibold">
        <Stethoscope class="size-4 text-primary" />
        {{ $t("medical.dashboard.title") }}
      </h3>
      <span class="text-xs text-primary">{{ $t("medical.dashboard.open") }}</span>
    </div>
    <div v-if="stats" class="mt-3 grid grid-cols-2 gap-3 sm:grid-cols-4">
      <div v-for="item in stats" :key="item.key">
        <p class="text-xs text-muted-foreground">{{ $t(`medical.dashboard.${item.key}`) }}</p>
        <p class="text-xl font-bold" :class="item.key === 'overdue' && item.value > 0 && 'text-red-600'">{{ item.value }}</p>
      </div>
    </div>
    <p v-else class="mt-3 text-sm text-muted-foreground">{{ $t("petCare.common.loading") }}</p>
  </router-link>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Stethoscope } from "lucide-vue-next";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { useMedicalQueue } from "@/features/admin/medical/queries/medicalVisits";
import { useMedicalReminders } from "@/features/admin/medical/queries/vaccinations";
import { useAuthStore } from "@/stores";
import { todayKey } from "../boarding/format";

const auth = useAuthStore();
const { branchId } = useCurrentBranch();
const visible = computed(() => auth.can("medical", "VIEW"));
const branch = computed(() => (visible.value ? branchId.value : undefined));

// Only asks while the account may read medical records; the queue already holds today's counts.
const queue = useMedicalQueue(branch, todayKey());
const overdue = useMedicalReminders(
  branch,
  { pageIndex: 1, pageSize: 1 },
  { scope: "overdue" }
);

const stats = computed(() => {
  const counts = queue.data.value?.counts;
  if (!counts) return null;
  return [
    { key: "waiting", value: counts.waiting },
    { key: "inProgress", value: counts.inProgress },
    { key: "toPay", value: counts.done },
    { key: "overdue", value: overdue.data.value?.total ?? 0 },
  ] as const;
});
</script>
