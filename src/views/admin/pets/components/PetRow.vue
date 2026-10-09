<template>
  <tr
    class="cursor-pointer border-t transition-colors hover:bg-muted/40"
    @click="emit('open', pet.id)"
  >
    <td class="px-4 py-3">
      <div class="flex min-w-0 items-center gap-3">
        <Avatar class="size-10">
          <AvatarImage v-if="pet.photoUrl" :src="pet.photoUrl" />
          <AvatarFallback class="bg-primary/15 font-semibold text-primary">
            {{ initials(pet.name) }}
          </AvatarFallback>
        </Avatar>
        <div class="min-w-0">
          <p class="flex items-center gap-2 font-semibold">
            <span class="truncate">{{ pet.name }}</span>
            <Icon v-if="pet.speciesIcon" :icon="pet.speciesIcon" class="size-4 shrink-0 text-muted-foreground" />
          </p>
          <p class="truncate text-xs text-muted-foreground">
            {{ [pet.speciesName, pet.breed, $t(`petCare.sex.${pet.sex}`)].filter(Boolean).join(" · ") }}
          </p>
          <div v-if="pet.allergies || pet.behaviorNotes" class="mt-1 flex flex-wrap gap-1">
            <span v-if="pet.allergies" class="rounded-full bg-red-100 px-2 py-0.5 text-[10px] font-semibold text-red-700">
              {{ $t("petCare.pets.tagAllergy") }}
            </span>
            <span v-if="pet.behaviorNotes" class="rounded-full bg-orange-100 px-2 py-0.5 text-[10px] font-semibold text-orange-700">
              {{ $t("petCare.pets.tagBehavior") }}
            </span>
          </div>
        </div>
      </div>
    </td>
    <td class="whitespace-nowrap px-4 py-3">{{ formatAge(pet.birthDate, t) }}</td>
    <td class="whitespace-nowrap px-4 py-3">
      <template v-if="pet.weightKg !== null">
        <p class="font-medium">
          {{ $t("petCare.common.kg", { n: pet.weightKg }) }}
          <span v-if="pet.weightMeasuredAt" class="text-xs font-normal text-muted-foreground">
            · {{ formatShortDate(pet.weightMeasuredAt) }}
          </span>
        </p>
        <span
          v-if="pet.bracketLabel"
          class="rounded-full bg-primary/10 px-2 py-0.5 text-[11px] font-medium text-primary"
        >
          {{ pet.bracketLabel }}
        </span>
      </template>
      <span v-else class="text-xs text-muted-foreground">{{ $t("petCare.pets.noWeight") }}</span>
    </td>
    <td class="px-4 py-3">
      <template v-if="pet.ownerName">
        <p class="font-medium">
          {{ pet.ownerName }}
          <span v-if="pet.ownerCount > 1" class="text-xs font-normal text-muted-foreground">
            {{ $t("petCare.pets.owners", { n: pet.ownerCount - 1 }) }}
          </span>
        </p>
        <p class="text-xs text-muted-foreground">{{ pet.ownerPhone }}</p>
      </template>
      <span v-else class="text-xs text-muted-foreground">{{ $t("petCare.pets.noOwner") }}</span>
    </td>
    <td class="px-4 py-3 text-right" @click.stop>
      <DropdownMenu>
        <DropdownMenuTrigger as-child>
          <Button variant="ghost" size="icon" class="size-8">
            <EllipsisVertical class="size-4" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem @click="emit('open', pet.id)">
            {{ $t("petCare.common.viewProfile") }}
          </DropdownMenuItem>
          <DropdownMenuItem
            v-if="canUpdate && pet.status === 'active'"
            @click="emit('archive', pet)"
          >
            {{ $t("petCare.common.archive") }}
          </DropdownMenuItem>
          <DropdownMenuItem v-else-if="canUpdate" @click="emit('restore', pet.id)">
            {{ $t("petCare.common.restore") }}
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </td>
  </tr>
</template>

<script lang="ts" setup>
import { useI18n } from "vue-i18n";
import { Icon } from "@iconify/vue";
import { EllipsisVertical } from "lucide-vue-next";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import type { PetListItem } from "@/repositories/pets";
import { formatAge, formatShortDate, initials } from "../format";

defineProps<{ pet: PetListItem; canUpdate: boolean }>();

const emit = defineEmits<{
  open: [petId: string];
  archive: [pet: PetListItem];
  restore: [petId: string];
}>();

const { t } = useI18n();
</script>
