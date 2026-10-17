<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <Settings2 class="size-4 text-primary" />
      {{ $t("boarding.settings.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-5">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <BoardingNav />
        <BranchPicker :model-value="branchId" :branches="branches" @update:model-value="selectBranch" />
      </div>

      <p v-if="!canSetup" class="rounded-lg border border-dashed bg-white px-4 py-3 text-sm text-muted-foreground">
        {{ $t("boarding.settings.readOnly") }}
      </p>

      <Tabs default-value="types" class="flex min-h-0 flex-1 flex-col">
        <TabsList class="self-start">
          <TabsTrigger value="types">{{ $t("boarding.settings.tabTypes") }}</TabsTrigger>
          <TabsTrigger value="kennels">{{ $t("boarding.settings.tabKennels") }}</TabsTrigger>
          <TabsTrigger value="rules">{{ $t("boarding.settings.tabRules") }}</TabsTrigger>
        </TabsList>
        <TabsContent value="types" class="mt-4 flex min-h-0 flex-1 flex-col">
          <KennelTypesCard :branch-id="branchId" :branches="branches" :can-edit="canSetup" />
        </TabsContent>
        <TabsContent value="kennels" class="mt-4 flex min-h-0 flex-1 flex-col">
          <KennelsCard :branch-id="branchId" :can-edit="canSetup" :can-update="canUpdate" />
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
import { ContentWrap, Header } from "@/features/admin/components";
import { BranchPicker } from "@/features/admin/pos";
import BoardingNav from "../BoardingNav.vue";
import KennelsCard from "./KennelsCard.vue";
import KennelTypesCard from "./KennelTypesCard.vue";
import RulesCard from "./RulesCard.vue";

const auth = useAuthStore();
const { branches, branchId, selectBranch } = useCurrentBranch();
const canSetup = computed(() => auth.can("boarding", "SETTING"));
const canUpdate = computed(() => auth.can("boarding", "UPDATE"));
</script>
