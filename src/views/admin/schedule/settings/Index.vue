<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <Settings2 class="size-4 text-primary" />
      {{ $t("spa.settings.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-5 overflow-y-auto">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <SpaNav />
        <BranchPicker :model-value="branchId" :branches="branches" @update:model-value="selectBranch" />
      </div>

      <p v-if="!canSetup" class="rounded-lg border border-dashed bg-white px-4 py-3 text-sm text-muted-foreground">
        {{ $t("spa.settings.readOnly") }}
      </p>

      <div class="grid gap-5 xl:grid-cols-2">
        <ResourcesCard :branch-id="branchId" :can-edit="canSetup" />
        <HoursCard :branch-id="branchId" :can-edit="canSetup" />
      </div>
      <StaffCard :branch-id="branchId" :can-edit="canSetup" />
    </div>
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Settings2 } from "lucide-vue-next";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { useAuthStore } from "@/stores";
import { ContentWrap, Header } from "@/views/admin/components";
import BranchPicker from "@/views/admin/pos/components/BranchPicker.vue";
import SpaNav from "../SpaNav.vue";
import HoursCard from "./HoursCard.vue";
import ResourcesCard from "./ResourcesCard.vue";
import StaffCard from "./StaffCard.vue";

const auth = useAuthStore();
const { branches, branchId, selectBranch } = useCurrentBranch();
const canSetup = computed(() => auth.can("schedule", "SETTING"));
</script>
