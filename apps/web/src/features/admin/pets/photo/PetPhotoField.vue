<template>
  <div class="flex items-center gap-4">
    <PetAvatar :name="name" :photo-url="previewUrl" :species-icon="speciesIcon" class="size-16" />
    <div class="space-y-1">
      <div class="flex flex-wrap gap-2">
        <Button type="button" variant="outline" size="sm" @click="picker?.click()">
          <ImagePlus class="mr-2 size-4" />
          {{ $t(file ? "petCare.pets.photo.change" : "petCare.pets.photo.add") }}
        </Button>
        <Button v-if="file" type="button" variant="ghost" size="sm" @click="file = null">
          {{ $t("petCare.pets.photo.remove") }}
        </Button>
      </div>
      <p class="text-xs text-muted-foreground">{{ $t("petCare.pets.photo.hint") }}</p>
    </div>
    <input ref="picker" type="file" accept="image/*" class="hidden" @change="onPick" />
  </div>
</template>

<script lang="ts" setup>
import { onBeforeUnmount, ref, watch } from "vue";
import { ImagePlus } from "lucide-vue-next";
import PetAvatar from "@/components/common/PetAvatar.vue";
import { Button } from "@/components/ui/button";

// An optional picture picked while registering a pet. It is only held here; the sheet uploads it
// once the pet exists.
defineProps<{ name: string; speciesIcon?: string | null }>();

const file = defineModel<File | null>({ required: true });
const picker = ref<HTMLInputElement | null>(null);
const previewUrl = ref<string | null>(null);

const dropPreview = () => {
  if (previewUrl.value) URL.revokeObjectURL(previewUrl.value);
  previewUrl.value = null;
};

watch(
  file,
  (value) => {
    dropPreview();
    if (value) previewUrl.value = URL.createObjectURL(value);
  },
  { immediate: true }
);
onBeforeUnmount(dropPreview);

const onPick = (event: Event) => {
  const input = event.target as HTMLInputElement;
  file.value = input.files?.[0] ?? null;
  input.value = "";
};
</script>
