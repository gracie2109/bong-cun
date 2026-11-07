<template>
  <template v-if="week?.requirePublish && canView">
    <Button variant="outline" class="border-amber-300 bg-amber-50 text-amber-900 hover:bg-amber-100" @click="open = true">
      <UserRoundX class="mr-1 size-4" />
      {{ $t("attendance.publish.missing.button", { count: week.missingCount ?? 0 }) }}
    </Button>
    <MissingRegistrationDrawer v-model:open="open" :branch-id="branchId" :monday="monday" :can-assign="canAssign" />
  </template>
</template>

<script lang="ts" setup>
import { ref } from "vue";
import { UserRoundX } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import type { WeekStatus } from "@bongcun/core/attendance";
import MissingRegistrationDrawer from "./MissingRegistrationDrawer.vue";

defineProps<{ branchId: string | undefined; monday: string; week: WeekStatus | undefined; canView: boolean; canAssign: boolean }>();
const open = ref(false);
</script>
