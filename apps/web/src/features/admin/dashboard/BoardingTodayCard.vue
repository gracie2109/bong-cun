<template>
  <router-link
    v-if="visible"
    :to="{ name: 'boardingBoard' }"
    class="block rounded-xl border bg-white p-4 transition-colors hover:border-primary hover:bg-primary/5"
  >
    <div class="flex flex-wrap items-center justify-between gap-2">
      <h3 class="flex items-center gap-2 text-sm font-semibold">
        <Home class="size-4 text-primary" />
        {{ $t("boarding.dashboard.title") }}
      </h3>
      <span class="text-xs text-primary">{{ $t("boarding.dashboard.open") }}</span>
    </div>
    <div v-if="counts" class="mt-3 grid grid-cols-2 gap-3 sm:grid-cols-4">
      <div v-for="key in KEYS" :key="key">
        <p class="text-xs text-muted-foreground">{{ $t(`boarding.board.stats.${key}`) }}</p>
        <p class="text-xl font-bold" :class="key === 'overdue' && counts.overdue > 0 && 'text-red-600'">{{ counts[key] }}</p>
      </div>
    </div>
    <p v-else class="mt-3 text-sm text-muted-foreground">{{ $t("petCare.common.loading") }}</p>
  </router-link>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Home } from "lucide-vue-next";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { useBoardingBoard } from "@/features/admin/boarding";
import { useAuthStore } from "@/stores";
import { todayKey } from "../boarding/format";

const KEYS = ["arriving", "departing", "occupied", "overdue"] as const;

const auth = useAuthStore();
const { branchId } = useCurrentBranch();
const visible = computed(() => auth.can("boarding", "VIEW"));

// Only asks while the account may read the hotel; the day board already holds today's counts.
const boardQuery = useBoardingBoard(
  computed(() => (visible.value ? branchId.value : undefined)),
  todayKey()
);
const counts = computed(() => boardQuery.data.value?.counts ?? null);
</script>
