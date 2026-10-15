<template>
  <tr class="border-t align-top">
    <td class="whitespace-nowrap px-4 py-3">
      <p class="font-semibold">{{ stay.code }}</p>
      <span class="mt-1 inline-block rounded-full px-2 py-0.5 text-[10px] font-semibold" :class="STAY_TONE[stay.status]">
        {{ $t(`boarding.status.${stay.status}`) }}
      </span>
    </td>
    <td class="whitespace-nowrap px-4 py-3">
      <p>{{ dateTime(stay.plannedInAt) }}</p>
      <p class="text-xs text-muted-foreground">→ {{ dateTime(stay.plannedOutAt) }}</p>
    </td>
    <td class="px-4 py-3">
      <p class="font-medium">{{ stay.customerName }}</p>
      <p class="text-xs text-muted-foreground">{{ stay.customerPhone }}</p>
    </td>
    <td class="px-4 py-3">
      <ul class="space-y-1">
        <li v-for="pet in stay.pets" :key="pet.id" :class="pet.status === 'cancelled' && 'text-muted-foreground line-through'">
          <span class="font-medium">{{ pet.petName }}</span>
          <span class="text-xs text-muted-foreground">· {{ pet.kennelCode }} ({{ pet.kennelTypeName }})</span>
        </li>
      </ul>
    </td>
    <td class="whitespace-nowrap px-4 py-3 text-right font-medium">{{ money(stay.estTotal) }}</td>
    <td class="whitespace-nowrap px-4 py-3 text-right">
      <div class="flex justify-end gap-2">
        <Button size="sm" variant="outline" as-child>
          <router-link :to="{ name: 'boardingStayDetail', params: { stayId: stay.id } }">{{ $t("boarding.detail.open") }}</router-link>
        </Button>
        <Button v-if="canNoShow" size="sm" variant="ghost" @click="emit('no-show')">{{ $t("boarding.stays.noShow") }}</Button>
        <Button v-if="canEdit" size="sm" variant="outline" @click="emit('edit')">{{ $t("petCare.common.edit") }}</Button>
      </div>
    </td>
  </tr>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import type { BoardingStay } from "@/types/boarding";
import { dateTime, money, STAY_TONE } from "../format";

defineProps<{ stay: BoardingStay; canEdit: boolean; canNoShow: boolean }>();
const emit = defineEmits<{ edit: []; "no-show": [] }>();
</script>
