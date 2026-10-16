<template>
  <tr class="border-t align-top" :class="!type.isActive && 'text-muted-foreground'">
    <td class="px-4 py-3">
      <p class="font-semibold">{{ type.name }}</p>
      <div class="mt-1 flex flex-wrap gap-1">
        <span class="rounded px-1.5 py-0.5 text-[10px] font-semibold" :class="VACCINE_KIND_TONE[type.kind]">
          {{ $t(`medical.vaccines.kinds.${type.kind}`) }}
        </span>
        <span v-if="!type.isActive" class="rounded bg-slate-200 px-1.5 py-0.5 text-[10px] font-semibold text-slate-700">
          {{ $t("medical.common.inactive") }}
        </span>
      </div>
    </td>
    <td class="px-4 py-3 text-xs">
      {{ type.speciesNames.length ? type.speciesNames.join(", ") : $t("medical.common.allSpecies") }}
    </td>
    <td class="px-4 py-3 text-xs">
      <p>{{ type.seriesDoses > 1 ? $t("medical.vaccines.seriesShort", { doses: type.seriesDoses, days: type.seriesIntervalDays ?? 0 }) : $t("medical.vaccines.seriesSingle") }}</p>
      <p class="text-muted-foreground">
        {{ type.boosterIntervalDays ? $t("medical.vaccines.boosterShort", { days: type.boosterIntervalDays }) : $t("medical.vaccines.noReminder") }}
      </p>
    </td>
    <td class="px-4 py-3 text-xs">
      <template v-if="type.productId">
        <p class="font-medium">{{ type.productName }}</p>
        <p v-if="type.stockQty !== null" :class="type.stockQty > 0 ? 'text-muted-foreground' : 'font-semibold text-red-600'">
          {{ $t("medical.vaccines.stock", { qty: type.stockQty, unit: type.productUnit ?? "" }) }}
        </p>
      </template>
      <span v-else class="text-muted-foreground">{{ $t("medical.vaccines.recordOnly") }}</span>
    </td>
    <td class="whitespace-nowrap px-4 py-3 text-right">
      <Button v-if="canEdit" size="sm" variant="outline" @click="emit('edit')">{{ $t("petCare.common.edit") }}</Button>
    </td>
  </tr>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import type { VaccineType } from "@bongcun/core/medical";
import { VACCINE_KIND_TONE } from "../format";

defineProps<{ type: VaccineType; canEdit: boolean }>();
const emit = defineEmits<{ edit: [] }>();
</script>
