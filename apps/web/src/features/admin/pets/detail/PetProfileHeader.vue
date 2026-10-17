<template>
  <div class="flex flex-wrap items-center gap-5 rounded-xl border bg-white p-5">
    <PetPhotoButton
      :pet-id="pet.id"
      :name="pet.name"
      :photo-url="pet.photoUrl"
      :species-icon="pet.speciesIcon"
      :can-update="canUpdate"
    />

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
      <p v-if="pet.status === 'deceased'" class="text-sm text-muted-foreground">
        {{ deceasedLine }}
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
          <DropdownMenuItem v-if="pet.status === 'archived'" @click="emit('changeStatus', 'active')">
            {{ $t("petCare.common.restore") }}
          </DropdownMenuItem>
          <DropdownMenuItem v-if="pet.status === 'deceased'" @click="emit('restoreDeceased')">
            {{ $t("petCare.common.restore") }}
          </DropdownMenuItem>
          <DropdownMenuItem v-if="pet.status === 'active'" @click="emit('changeStatus', 'archived')">
            {{ $t("petCare.common.archive") }}
          </DropdownMenuItem>
          <DropdownMenuItem v-if="pet.status === 'active'" @click="emit('markDeceased')">
            {{ $t("petCare.pets.detail.markDeceased") }}
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import { Icon } from "@iconify/vue";
import { Banknote, EllipsisVertical, Pencil } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import type { PetProfile, PetStatus } from "@bongcun/supabase/pets";
import { formatAge, formatDate } from "../format";
import PetPhotoButton from "../photo/PetPhotoButton.vue";

const props = defineProps<{
  pet: PetProfile;
  canUpdate: boolean;
  /** Prefills the price check for this pet's weight. */
  latestWeightKg?: number;
}>();

const emit = defineEmits<{
  edit: [];
  changeStatus: [status: PetStatus];
  markDeceased: [];
  restoreDeceased: [];
}>();

const { t } = useI18n();

const deceasedLine = computed(() =>
  [
    props.pet.deceasedOn ? t("petCare.pets.deceased.on", { date: formatDate(props.pet.deceasedOn) }) : "",
    props.pet.deceasedNote,
  ]
    .filter(Boolean)
    .join(" · ")
);
</script>
