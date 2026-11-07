<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <Settings2 class="size-4 text-primary" />
      {{ $t("attendance.settings.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-5">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <AttendanceNav />
        <BranchPicker :model-value="branchId" :branches="branches" @update:model-value="selectBranch" />
      </div>

      <p v-if="!canSetup" class="rounded-lg border border-dashed bg-white px-4 py-3 text-sm text-muted-foreground">
        {{ $t("attendance.settings.readOnly") }}
      </p>

      <div class="grid min-h-0 flex-1 content-start gap-5 overflow-y-auto xl:grid-cols-2">
        <TemplatesCard :branch-id="branchId" :can-edit="canSetup" />
        <RulesCard :branch-id="branchId" :can-edit="canSetup" />
        <RegistrationCard :branch-id="branchId" :can-edit="canSetup" class="xl:col-span-2" />
        <AllowancesCard :branch-id="branchId" :can-edit="canSetup" class="xl:col-span-2" />
      </div>
    </div>
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Settings2 } from "lucide-vue-next";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { useAuthStore } from "@/stores";
import { ContentWrap, Header } from "@/features/admin/components";
import { BranchPicker } from "@/features/admin/pos";
import AttendanceNav from "../AttendanceNav.vue";
import AllowancesCard from "./AllowancesCard.vue";
import RegistrationCard from "./RegistrationCard.vue";
import RulesCard from "./RulesCard.vue";
import TemplatesCard from "./TemplatesCard.vue";

const auth = useAuthStore();
const { branches, branchId, selectBranch } = useCurrentBranch();
const canSetup = computed(() => auth.can("attendance", "SETTING"));
</script>
