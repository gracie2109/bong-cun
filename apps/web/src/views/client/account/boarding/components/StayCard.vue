<template>
  <li class="space-y-3 rounded-xl border bg-white p-4">
    <div class="flex flex-wrap items-start justify-between gap-2">
      <div>
        <p class="font-mono text-sm font-semibold">{{ stay.code }}</p>
        <p class="font-semibold">{{ dayLabel(dayOf(stay.plannedInAt), locale) }}</p>
        <p class="text-sm text-primary">
          {{ $t("client.boarding.until", { day: dayLabel(dayOf(stay.plannedOutAt), locale) }) }}
        </p>
      </div>
      <span class="rounded-full px-2.5 py-0.5 text-xs font-semibold" :class="STATUS_TONE[stay.status] ?? 'bg-muted text-muted-foreground'">
        {{ $t(`client.boarding.status.${stay.status}`) }}
      </span>
    </div>

    <p class="text-sm text-muted-foreground">{{ stay.branchName }}</p>

    <ul class="divide-y rounded-lg border text-sm">
      <li v-for="(pet, index) in stay.pets" :key="index" class="flex items-start justify-between gap-3 px-3 py-2" :class="pet.status === 'cancelled' && 'text-muted-foreground line-through'">
        <span><span class="font-medium">{{ pet.petName }}</span> · {{ pet.kennelTypeName }}</span>
        <span class="shrink-0 text-muted-foreground">{{ $t("client.boarding.nights", { n: pet.chargedNights }) }}</span>
      </li>
    </ul>

    <div class="flex flex-wrap items-center justify-between gap-2">
      <p class="text-sm">
        {{ stay.isFinal ? $t("client.boarding.total") : $t("client.boarding.estimate") }}:
        <span class="font-semibold text-primary">{{ formatPrice(stay.estTotal) }}</span>
      </p>
      <Button as-child size="sm" variant="outline">
        <RouterLink :to="{ name: 'account-boarding-detail', params: { id: stay.id } }">{{ $t("client.boarding.view") }}</RouterLink>
      </Button>
    </div>
  </li>
</template>

<script lang="ts" setup>
import { useI18n } from "vue-i18n";
import { Button } from "@/components/ui/button";
import { formatPrice } from "@/lib/utils";
import type { MyBoardingStay } from "@/types/account";
import { dayLabel } from "@/utils/spa/booking";
import { dayOf, STATUS_TONE } from "../format";

defineProps<{ stay: MyBoardingStay }>();
const { locale } = useI18n();
</script>
