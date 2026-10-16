<template>
  <tr class="border-t align-top">
    <td class="whitespace-nowrap px-4 py-3">
      <p class="font-semibold">{{ visit.code }}</p>
      <span class="mt-1 inline-block rounded-full px-2 py-0.5 text-[10px] font-semibold" :class="VISIT_TONE[visit.status]">
        {{ $t(`medical.status.${visit.status}`) }}
      </span>
    </td>
    <td class="whitespace-nowrap px-4 py-3">{{ dateTime(visit.checkedInAt ?? visit.scheduledAt ?? visit.createdAt) }}</td>
    <td class="px-4 py-3">
      <p class="font-medium">{{ visit.petName }}</p>
      <p class="text-xs text-muted-foreground">{{ visit.speciesName }}</p>
    </td>
    <td class="px-4 py-3">
      <p class="font-medium">{{ visit.customerName }}</p>
      <p class="text-xs text-muted-foreground">{{ visit.customerPhone }}</p>
    </td>
    <td class="px-4 py-3">{{ visit.vetName ?? "-" }}</td>
    <td class="max-w-[16rem] px-4 py-3">
      <p class="line-clamp-2">{{ visit.diagnosesText ?? visit.reason ?? "-" }}</p>
    </td>
    <td class="whitespace-nowrap px-4 py-3">{{ visit.outcome ? $t(`medical.outcome.${visit.outcome}`) : "-" }}</td>
    <td class="whitespace-nowrap px-4 py-3 text-right">{{ money(visit.estTotal) }}</td>
    <td class="whitespace-nowrap px-4 py-3 text-right">
      <Button size="sm" variant="outline" as-child>
        <router-link :to="{ name: 'medicalVisitDetail', params: { visitId: visit.id } }">{{ $t("medical.visits.open") }}</router-link>
      </Button>
    </td>
  </tr>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import type { MedicalVisit } from "@bongcun/core/medical";
import { dateTime, money, VISIT_TONE } from "../format";

defineProps<{ visit: MedicalVisit }>();
</script>
