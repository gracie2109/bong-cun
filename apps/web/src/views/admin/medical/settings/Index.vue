<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <Settings2 class="size-4 text-primary" />
      {{ $t("medical.settings.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-5">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <MedicalNav />
        <BranchPicker :model-value="branchId" :branches="branches" @update:model-value="selectBranch" />
      </div>

      <p v-if="!canSetup" class="rounded-lg border border-dashed bg-white px-4 py-3 text-sm text-muted-foreground">
        {{ $t("medical.settings.readOnly") }}
      </p>

      <Tabs default-value="diagnoses" class="flex min-h-0 flex-1 flex-col">
        <TabsList class="self-start">
          <TabsTrigger value="diagnoses">{{ $t("medical.settings.tabDiagnoses") }}</TabsTrigger>
          <TabsTrigger value="vaccines">{{ $t("medical.settings.tabVaccines") }}</TabsTrigger>
          <TabsTrigger value="rules">{{ $t("medical.settings.tabRules") }}</TabsTrigger>
        </TabsList>
        <TabsContent value="diagnoses" class="mt-4 flex min-h-0 flex-1 flex-col">
          <DiagnosisTermsCard :can-edit="canSetup" />
        </TabsContent>
        <TabsContent value="vaccines" class="mt-4 flex min-h-0 flex-1 flex-col">
          <VaccineTypesCard :branch-id="branchId" :can-edit="canSetup" />
        </TabsContent>
        <TabsContent value="rules" class="mt-4 overflow-y-auto">
          <RulesCard :branch-id="branchId" :can-edit="canSetup" />
        </TabsContent>
      </Tabs>
    </div>
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Settings2 } from "lucide-vue-next";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { useAuthStore } from "@/stores";
import { ContentWrap, Header } from "@/views/admin/components";
import BranchPicker from "@/views/admin/pos/components/BranchPicker.vue";
import MedicalNav from "../MedicalNav.vue";
import DiagnosisTermsCard from "./DiagnosisTermsCard.vue";
import RulesCard from "./RulesCard.vue";
import VaccineTypesCard from "./VaccineTypesCard.vue";

const auth = useAuthStore();
const { branches, branchId, selectBranch } = useCurrentBranch();
const canSetup = computed(() => auth.can("medical", "SETTING"));
</script>
