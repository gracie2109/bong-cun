<template>
  <tr class="border-t align-top" :class="!term.isActive && 'text-muted-foreground'">
    <td class="px-4 py-3">
      <p class="font-semibold">{{ term.name }}</p>
      <div class="mt-1 flex flex-wrap gap-1">
        <span v-if="!term.isActive" class="rounded bg-slate-200 px-1.5 py-0.5 text-[10px] font-semibold text-slate-700">
          {{ $t("medical.common.inactive") }}
        </span>
        <span v-if="term.isContagious" class="rounded bg-red-100 px-1.5 py-0.5 text-[10px] font-semibold text-red-700">
          {{ $t("medical.diagnoses.contagiousTag") }}
        </span>
      </div>
    </td>
    <td class="px-4 py-3 text-xs">
      {{ term.speciesNames.length ? term.speciesNames.join(", ") : $t("medical.common.allSpecies") }}
    </td>
    <td class="whitespace-nowrap px-4 py-3 text-right">
      <Button v-if="canEdit" size="sm" variant="outline" @click="emit('edit')">{{ $t("petCare.common.edit") }}</Button>
    </td>
  </tr>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import type { DiagnosisTerm } from "@bongcun/core/medical";

defineProps<{ term: DiagnosisTerm; canEdit: boolean }>();
const emit = defineEmits<{ edit: [] }>();
</script>
