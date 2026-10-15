<template>
  <tr class="border-t align-top" :class="!type.isActive && 'text-muted-foreground'">
    <td class="px-4 py-3">
      <p class="font-semibold">{{ type.name }}</p>
      <p v-if="type.description" class="line-clamp-2 max-w-xs text-xs text-muted-foreground">{{ type.description }}</p>
      <div class="mt-1 flex flex-wrap gap-1">
        <span v-if="!type.isActive" class="rounded bg-slate-200 px-1.5 py-0.5 text-[10px] font-semibold text-slate-700">
          {{ $t("boarding.common.inactive") }}
        </span>
        <span v-if="type.isPublic" class="rounded bg-sky-100 px-1.5 py-0.5 text-[10px] font-semibold text-sky-700">
          {{ $t("boarding.types.public") }}
        </span>
      </div>
    </td>
    <td class="px-4 py-3 text-xs">
      {{ type.speciesNames.length ? type.speciesNames.join(", ") : $t("boarding.types.allSpecies") }}
    </td>
    <td class="whitespace-nowrap px-4 py-3 text-xs">
      <p>{{ type.maxWeightKg ? $t("boarding.types.upToKg", { kg: type.maxWeightKg }) : $t("boarding.types.noLimit") }}</p>
      <p class="text-muted-foreground">{{ $t("boarding.types.petsPerKennel", { count: type.maxPets }) }}</p>
    </td>
    <td class="whitespace-nowrap px-4 py-3">
      <p class="font-semibold">{{ money(type.nightPrice) }}</p>
      <p v-if="type.maxPets > 1" class="text-xs text-muted-foreground">
        {{ $t("boarding.types.extraPetShort", { price: money(type.extraPetNightPrice) }) }}
      </p>
      <p v-if="type.hasBranchPrice" class="text-[10px] font-semibold text-primary">{{ $t("boarding.types.branchPriceTag") }}</p>
    </td>
    <td class="px-4 py-3 text-center">{{ type.kennelCount }}</td>
    <td class="whitespace-nowrap px-4 py-3 text-right">
      <Button v-if="canEdit" size="sm" variant="outline" @click="emit('edit')">{{ $t("petCare.common.edit") }}</Button>
    </td>
  </tr>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import type { KennelType } from "@/types/boarding";
import { money } from "../format";

defineProps<{ type: KennelType; canEdit: boolean }>();
const emit = defineEmits<{ edit: [] }>();
</script>
