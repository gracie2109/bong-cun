<template>
  <div class="relative shrink-0">
    <PetAvatar :name="name" :photo-url="photoUrl" :species-icon="speciesIcon" :class="sizeClass ?? 'size-24'" />

    <DropdownMenu v-if="canUpdate">
      <DropdownMenuTrigger as-child>
        <Button
          type="button"
          size="icon"
          variant="secondary"
          class="absolute -bottom-1 -right-1 size-8 rounded-full border bg-white shadow-sm"
          :disabled="uploading"
          :aria-label="$t('petCare.pets.photo.change')"
        >
          <Loader2 v-if="uploading" class="size-4 animate-spin" />
          <Camera v-else class="size-4" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="start">
        <DropdownMenuItem @click="picker?.click()">
          <ImagePlus class="mr-2 size-4" />
          {{ $t("petCare.pets.photo.change") }}
        </DropdownMenuItem>
        <DropdownMenuItem v-if="photoUrl" class="text-destructive" @click="remove()">
          <Trash2 class="mr-2 size-4" />
          {{ $t("petCare.pets.photo.remove") }}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>

    <input ref="picker" type="file" accept="image/*" class="hidden" @change="onPick" />
  </div>
</template>

<script lang="ts" setup>
import { ref, toRef } from "vue";
import { Camera, ImagePlus, Loader2, Trash2 } from "lucide-vue-next";
import PetAvatar from "@/components/common/PetAvatar.vue";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { usePetPhoto } from "./usePetPhoto";

// The pet's photo with a camera button (hidden without the pets UPDATE permission) to change or remove it.
const props = defineProps<{
  petId: string;
  name: string;
  photoUrl?: string | null;
  speciesIcon?: string | null;
  canUpdate: boolean;
  sizeClass?: string;
}>();

const picker = ref<HTMLInputElement | null>(null);
const { uploading, change, remove } = usePetPhoto(toRef(props, "petId"));

const onPick = async (event: Event) => {
  const input = event.target as HTMLInputElement;
  const file = input.files?.[0];
  input.value = "";
  if (file) await change(file);
};
</script>
