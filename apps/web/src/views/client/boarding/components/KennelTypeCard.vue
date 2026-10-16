<template>
  <article class="flex h-full flex-col rounded-3xl bg-white p-5 ring-1 ring-border/70">
    <img v-if="type.photoUrl" :src="type.photoUrl" :alt="type.name" class="mb-4 aspect-[4/3] w-full rounded-2xl object-cover" loading="lazy" />
    <h3 class="text-lg font-bold tracking-tight">{{ type.name }}</h3>
    <p v-if="type.description" class="mt-1 text-sm text-muted-foreground">{{ type.description }}</p>
    <p class="mt-3 text-2xl font-extrabold text-sage">
      {{ formatPrice(type.nightPrice) }}<span class="text-sm font-medium text-muted-foreground"> / {{ $t("client.boarding.night") }}</span>
    </p>
    <ul class="mt-3 space-y-1 text-sm text-muted-foreground">
      <li v-if="type.species.length">{{ $t("client.boarding.speciesLabel") }}: {{ type.species.join(", ") }}</li>
      <li v-if="type.maxWeightKg">{{ $t("client.boarding.maxWeight", { kg: type.maxWeightKg }) }}</li>
      <li v-if="type.maxPets > 1">
        {{ $t("client.boarding.sharing", { n: type.maxPets }) }}
        <template v-if="type.extraPetNightPrice !== null">
          — {{ $t("client.boarding.extraPet", { price: formatPrice(type.extraPetNightPrice) }) }}
        </template>
      </li>
    </ul>
  </article>
</template>

<script lang="ts" setup>
import { formatPrice } from "@/lib/utils";
import type { BoardingWebKennelType } from "@/types/boardingWeb";

defineProps<{ type: BoardingWebKennelType }>();
</script>
