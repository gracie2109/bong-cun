<template>
  <div class="space-y-4">
    <CareLogForm v-if="canWrite" :pets="pets" />

    <p v-if="logs.length === 0" class="rounded-xl border border-dashed bg-white p-6 text-center text-sm text-muted-foreground">
      {{ $t("boarding.care.empty") }}
    </p>
    <ol v-else class="space-y-2">
      <li v-for="log in logs" :key="log.id" class="flex items-start justify-between gap-3 rounded-xl border bg-white px-4 py-3">
        <div class="min-w-0 space-y-0.5 text-sm">
          <p class="font-semibold">
            {{ log.petName }} · {{ $t(`boarding.care.kinds.${log.kind}`) }}
            <span v-if="log.mealEaten" class="font-normal text-muted-foreground">· {{ $t(`boarding.care.meal.${log.mealEaten}`) }}</span>
            <EyeOff v-if="!log.visibleToCustomer" class="ml-1 inline size-3.5 text-muted-foreground" :aria-label="$t('boarding.care.hidden')" />
          </p>
          <p v-if="log.content" class="whitespace-pre-line">{{ log.content }}</p>
          <p class="text-xs text-muted-foreground">{{ dateTime(log.loggedAt) }}<template v-if="log.createdByName"> · {{ log.createdByName }}</template></p>
        </div>
        <Button v-if="log.canDelete" variant="ghost" size="icon" class="size-8 shrink-0" :aria-label="$t('petCare.common.cancel')" @click="remove.mutate(log.id)">
          <Trash2 class="size-4" />
        </Button>
      </li>
    </ol>
  </div>
</template>

<script lang="ts" setup>
import { EyeOff, Trash2 } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { useDeleteCareLog } from "@/queries/boarding";
import type { CareLog, StayPet } from "@bongcun/core/boarding";
import { dateTime } from "../format";
import CareLogForm from "./CareLogForm.vue";

defineProps<{ logs: CareLog[]; pets: StayPet[]; canWrite: boolean }>();
const remove = useDeleteCareLog();
</script>
