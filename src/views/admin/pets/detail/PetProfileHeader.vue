<template>
  <div class="flex flex-wrap items-center gap-5 rounded-xl border bg-white p-5">
    <Avatar class="size-24">
      <AvatarImage v-if="pet.photoUrl" :src="pet.photoUrl" />
      <AvatarFallback class="bg-primary/15 text-2xl font-semibold text-primary">
        {{ initials(pet.name) }}
      </AvatarFallback>
    </Avatar>

    <div class="min-w-0 flex-1 space-y-2">
      <div class="flex flex-wrap items-center gap-2">
        <h2 class="text-2xl font-bold">{{ pet.name }}</h2>
        <span
          class="rounded-full px-2 py-0.5 text-[11px] font-semibold"
          :class="pet.status === 'active' ? 'bg-emerald-100 text-emerald-700' : 'bg-muted text-muted-foreground'"
        >
          {{ $t(`petCare.status.${pet.status}`) }}
        </span>
      </div>
      <p class="flex flex-wrap items-center gap-x-2 text-sm text-muted-foreground">
        <Icon v-if="pet.speciesIcon" :icon="pet.speciesIcon" class="size-4" />
        {{ [pet.speciesName, pet.breed].filter(Boolean).join(" · ") }}
        <span>· {{ $t(`petCare.sex.${pet.sex}`) }}</span>
        <span v-if="pet.neutered">· {{ $t("petCare.pets.neutered") }}</span>
        <span v-if="pet.birthDate">
          · {{ $t("petCare.pets.detail.born", { date: formatDate(pet.birthDate) }) }}
          ({{ formatAge(pet.birthDate, t) }})
        </span>
      </p>
      <p v-if="pet.microchip" class="text-xs text-muted-foreground">
        Microchip: {{ pet.microchip }}
      </p>
      <div v-if="pet.allergies || pet.behaviorNotes" class="flex flex-wrap gap-2">
        <span v-if="pet.allergies" class="rounded-full bg-red-100 px-3 py-1 text-xs font-semibold text-red-700">
          {{ $t("petCare.pets.tagAllergy") }}: {{ pet.allergies }}
        </span>
        <span v-if="pet.behaviorNotes" class="rounded-full bg-orange-100 px-3 py-1 text-xs font-semibold text-orange-700">
          {{ pet.behaviorNotes }}
        </span>
      </div>
    </div>

    <div class="flex flex-wrap gap-2">
      <Button variant="outline" as-child>
        <router-link :to="{ name: 'petPrices', query: { speciesId: pet.speciesId, weight: latestWeightKg } }">
          <Banknote class="mr-2 size-4" />
          {{ $t("petCare.pets.detail.checkPrice") }}
        </router-link>
      </Button>
      <Button v-if="canUpdate" variant="outline" @click="emit('edit')">
        <Pencil class="mr-2 size-4" />
        {{ $t("petCare.pets.detail.editProfile") }}
      </Button>
      <DropdownMenu v-if="canUpdate">
        <DropdownMenuTrigger as-child>
          <Button variant="ghost" size="icon"><EllipsisVertical class="size-4" /></Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem v-if="pet.status !== 'active'" @click="emit('changeStatus', 'active')">
            {{ $t("petCare.common.restore") }}
          </DropdownMenuItem>
          <DropdownMenuItem v-if="pet.status === 'active'" @click="emit('changeStatus', 'archived')">
            {{ $t("petCare.common.archive") }}
          </DropdownMenuItem>
          <DropdownMenuItem v-if="pet.status === 'active'" @click="emit('changeStatus', 'deceased')">
            {{ $t("petCare.pets.detail.markDeceased") }}
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { useI18n } from "vue-i18n";
import { Icon } from "@iconify/vue";
import { Banknote, EllipsisVertical, Pencil } from "lucide-vue-next";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import type { PetProfile, PetStatus } from "@/repositories/pets";
import { formatAge, formatDate, initials } from "../format";

defineProps<{
  pet: PetProfile;
  canUpdate: boolean;
  /** Prefills the price check for this pet's weight. */
  latestWeightKg?: number;
}>();

const emit = defineEmits<{ edit: []; changeStatus: [status: PetStatus] }>();

const { t } = useI18n();
</script>
