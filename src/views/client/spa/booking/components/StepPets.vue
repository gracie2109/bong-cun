<template>
  <div class="space-y-3">
    <p class="text-sm text-muted-foreground">{{ $t("client.booking.petsHint") }}</p>
    <details
      v-for="(pet, index) in pets"
      :key="pet.id"
      class="rounded-xl border bg-white"
      :open="index === 0 || Boolean(picks[pet.id])"
    >
      <summary class="flex cursor-pointer items-center justify-between gap-2 p-4">
        <span class="font-semibold">
          {{ pet.name }}
          <span class="font-normal text-muted-foreground">· {{ pet.speciesName }}</span>
        </span>
        <span v-if="picks[pet.id]" class="rounded-full bg-primary/10 px-2 py-0.5 text-xs font-medium text-primary">
          {{ $t("client.booking.picked", { n: picks[pet.id].length }) }}
        </span>
      </summary>
      <div class="space-y-3 border-t p-4">
        <p v-if="combosOf(pet).length === 0 && servicesOf(pet).length === 0" class="text-sm text-muted-foreground">
          {{ $t("client.booking.noOffer") }}
        </p>
        <template v-if="combosOf(pet).length">
          <h3 class="text-xs font-semibold uppercase text-muted-foreground">{{ $t("client.spa.combos") }}</h3>
          <OfferRow
            v-for="combo in combosOf(pet)"
            :key="combo.id"
            :pick="pickOfCombo(combo)"
            :checked="hasPick(picks[pet.id], 'combo', combo.id)"
            :detail="combo.serviceNames.join(' + ')"
            @toggle="emit('toggle', pet.id, $event)"
          />
        </template>
        <template v-if="servicesOf(pet).length">
          <h3 class="text-xs font-semibold uppercase text-muted-foreground">{{ $t("client.spa.services") }}</h3>
          <OfferRow
            v-for="service in servicesOf(pet)"
            :key="service.id"
            :pick="pickOfService(service)"
            :checked="hasPick(picks[pet.id], 'service', service.id)"
            :detail="service.description"
            @toggle="emit('toggle', pet.id, $event)"
          />
        </template>
      </div>
    </details>
  </div>
</template>

<script lang="ts" setup>
import type { MyPet } from "@/types/account";
import type { SpaCatalog } from "@/types/spaCatalog";
import type { BookingPick } from "@/types/spaWeb";
import { hasPick, pickOfCombo, pickOfService, type PicksByPet } from "@/utils/spa/booking";
import { combosForSpecies, servicesForSpecies } from "@/utils/spa/catalog";
import OfferRow from "./OfferRow.vue";

const props = defineProps<{ pets: MyPet[]; catalog: SpaCatalog | null; picks: PicksByPet }>();
const emit = defineEmits<{ toggle: [petId: string, pick: BookingPick] }>();

const combosOf = (pet: MyPet) => (props.catalog ? combosForSpecies(props.catalog, pet.speciesId) : []);
const servicesOf = (pet: MyPet) => (props.catalog ? servicesForSpecies(props.catalog, pet.speciesId) : []);
</script>
