<template>
  <Popover>
    <PopoverTrigger as-child>
      <button
        type="button"
        class="flex items-center gap-2 rounded-md border px-1.5 py-1 text-left text-xs hover:bg-muted"
        :disabled="images.length === 0"
      >
        <ProductThumb :src="modelValue || null" class="size-8 shrink-0" />
        <span class="text-muted-foreground">
          {{ modelValue ? $t("products.images.picked") : $t("products.images.useCover") }}
        </span>
      </button>
    </PopoverTrigger>
    <PopoverContent class="w-64 p-2" align="end">
      <div class="grid grid-cols-4 gap-2">
        <button
          v-for="image in images"
          :key="image.key"
          type="button"
          class="relative overflow-hidden rounded-md border-2"
          :class="modelValue === image.url ? 'border-primary' : 'border-transparent'"
          @click="emit('update:modelValue', image.url)"
        >
          <ProductThumb :src="image.url" class="aspect-square w-full" />
        </button>
      </div>
      <Button type="button" variant="ghost" size="sm" class="mt-2 w-full" @click="emit('update:modelValue', '')">
        {{ $t("products.images.useCover") }}
      </Button>
    </PopoverContent>
  </Popover>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import ProductThumb from "../ProductThumb.vue";
import type { GalleryImage } from "./useImageGallery";

/** Chooses a variant's picture from the group's gallery; "" means the cover. */
defineProps<{ modelValue: string; images: GalleryImage[] }>();
const emit = defineEmits<{ "update:modelValue": [url: string] }>();
</script>
