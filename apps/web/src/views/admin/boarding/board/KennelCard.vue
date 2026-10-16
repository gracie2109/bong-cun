<template>
  <button
    type="button"
    class="flex min-h-28 flex-col gap-1.5 rounded-xl border p-3 text-left transition-shadow hover:shadow-md"
    :class="[KENNEL_STATE_TONE[kennel.state], !clickable && 'cursor-default hover:shadow-none']"
    @click="emit('open')"
  >
    <div class="flex items-center justify-between gap-2">
      <p class="flex items-center gap-1.5 font-semibold">
        <span class="size-2 rounded-full" :class="KENNEL_STATE_DOT[kennel.state]" />
        {{ kennel.code }}
      </p>
      <span class="text-[10px] font-semibold uppercase text-muted-foreground">{{ $t(`boarding.board.state.${kennel.state}`) }}</span>
    </div>

    <ul v-if="kennel.pets.length" class="space-y-0.5 text-sm">
      <li v-for="pet in kennel.pets" :key="pet.stayPetId">
        <span class="font-medium">{{ pet.petName }}</span>
        <span v-if="pet.hasNotes" class="ml-1 text-amber-600" :title="$t('boarding.board.hasNotes')">⚠</span>
        <span class="block text-xs text-muted-foreground">{{ pet.customerName }} · → {{ dateTime(pet.plannedOutAt) }}</span>
      </li>
    </ul>

    <ul v-if="kennel.arriving.length" class="space-y-0.5 border-t border-dashed pt-1.5 text-xs text-sky-800">
      <li v-for="pet in kennel.arriving" :key="pet.stayPetId">
        {{ $t("boarding.board.arrives", { pet: pet.petName, time: timeOf(pet.plannedInAt) }) }}
      </li>
    </ul>

    <p v-if="kennel.conflict" class="text-xs font-semibold text-red-600">{{ $t("boarding.board.conflict") }}</p>

    <Button v-if="kennel.status === 'cleaning' && canUpdate" size="sm" variant="outline" class="mt-auto h-7" @click.stop="emit('clean')">
      {{ $t("boarding.kennels.markClean") }}
    </Button>
  </button>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Button } from "@/components/ui/button";
import type { BoardKennel } from "@/types/boarding";
import { dateTime, KENNEL_STATE_DOT, KENNEL_STATE_TONE, timeOf } from "../format";

const props = defineProps<{ kennel: BoardKennel; canCreate: boolean; canUpdate: boolean }>();
const emit = defineEmits<{ open: []; clean: [] }>();

const clickable = computed(
  () =>
    (props.kennel.state === "free" && props.kennel.status === "ready" && props.canCreate) ||
    props.kennel.pets.length > 0 ||
    props.kennel.arriving.length > 0
);
</script>
