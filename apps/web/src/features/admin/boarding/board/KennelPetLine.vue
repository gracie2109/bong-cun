<template>
  <li>
    <PetAvatar :name="pet.petName" :photo-url="pet.petPhotoUrl" class="mr-1 inline-flex size-5 align-middle text-[9px]" />
    <span class="font-medium">{{ pet.petName }}</span>
    <span v-if="pet.kind === 'inpatient'" class="ml-1 rounded-full bg-violet-100 px-1.5 py-0.5 text-[10px] font-semibold text-violet-800">
      {{ $t("boarding.board.inpatient") }}<template v-if="pet.visitCode"> · {{ pet.visitCode }}</template>
    </span>
    <span v-if="pet.hasNotes" class="ml-1 text-amber-600" :title="$t('boarding.board.hasNotes')">⚠</span>
    <span class="block text-xs text-muted-foreground">{{ pet.customerName }} · → {{ dateTime(pet.plannedOutAt) }}</span>
  </li>
</template>

<script lang="ts" setup>
import PetAvatar from "@/components/common/PetAvatar.vue";
import type { BoardPet } from "@bongcun/core/boarding";
import { dateTime } from "../format";

defineProps<{ pet: BoardPet }>();
</script>
