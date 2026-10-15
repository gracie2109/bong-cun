<template>
  <p v-if="!logs.length" class="rounded-xl border border-dashed py-8 text-center text-sm text-muted-foreground">
    {{ $t("client.boarding.noLogs") }}
  </p>
  <ol v-else class="space-y-3">
    <li v-for="log in logs" :key="log.id" class="rounded-lg border bg-white px-3 py-2 text-sm">
      <div class="flex flex-wrap items-center justify-between gap-2">
        <span class="font-medium">
          {{ $t(`boarding.care.kinds.${log.kind}`) }}
          <span class="text-muted-foreground">· {{ log.petName }}</span>
        </span>
        <span class="text-xs text-muted-foreground">{{ logTime(log.loggedAt) }}</span>
      </div>
      <p v-if="log.mealEaten" class="mt-1 text-muted-foreground">{{ $t(`boarding.care.meal.${log.mealEaten}`) }}</p>
      <p v-if="log.content" class="mt-1">{{ log.content }}</p>
    </li>
  </ol>
</template>

<script lang="ts" setup>
import type { MyBoardingLog } from "@/types/account";
import { logTime } from "../format";

defineProps<{ logs: MyBoardingLog[] }>();
</script>
