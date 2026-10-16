<template>
  <section class="space-y-3">
    <div class="flex flex-wrap items-end justify-between gap-3">
      <div>
        <h3 class="font-semibold">{{ $t("products.images.title", { n: images.length, max: MAX }) }}</h3>
        <p class="text-xs text-muted-foreground">{{ $t("products.images.hint") }}</p>
      </div>
      <Button type="button" variant="outline" size="sm" :disabled="uploading || images.length >= MAX" @click="open()">
        <Loader2 v-if="uploading" class="mr-2 size-4 animate-spin" />
        <ImagePlus v-else class="mr-2 size-4" />
        {{ $t("products.images.add") }}
      </Button>
    </div>

    <p v-if="error" class="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
      {{ error.startsWith("max:") ? $t("products.images.max", { n: MAX }) : error }}
    </p>

    <p v-if="images.length === 0" class="rounded-xl border border-dashed py-12 text-center text-sm text-muted-foreground">
      {{ $t("products.images.empty") }}
    </p>
    <ul v-else class="grid grid-cols-3 gap-3 sm:grid-cols-4 lg:grid-cols-6">
      <li
        v-for="(image, index) in images"
        :key="image.key"
        class="group relative cursor-grab overflow-hidden rounded-lg border bg-white"
        :class="dragOver === index ? 'ring-2 ring-primary' : ''"
        draggable="true"
        @dragstart="dragFrom = index"
        @dragover.prevent="dragOver = index"
        @dragleave="dragOver = -1"
        @drop.prevent="drop(index)"
        @dragend="dragFrom = -1; dragOver = -1"
      >
        <ProductThumb :src="image.url" class="aspect-square w-full" />
        <span v-if="index === 0" class="absolute left-1 top-1 rounded bg-primary px-1.5 py-0.5 text-[10px] font-semibold text-primary-foreground">
          {{ $t("products.images.cover") }}
        </span>
        <div class="absolute inset-x-0 bottom-0 flex justify-between gap-1 bg-white/80 p-1 opacity-0 backdrop-blur-sm transition-opacity group-hover:opacity-100 focus-within:opacity-100">
          <Button v-if="index > 0" type="button" variant="ghost" size="sm" class="h-7 px-2 text-xs" @click="emit('makeCover', index)">
            {{ $t("products.images.makeCover") }}
          </Button>
          <span v-else />
          <Button type="button" variant="ghost" size="icon" class="size-7 text-red-600" :aria-label="$t('common.delete')" @click="emit('remove', index)">
            <Trash2 class="size-4" />
          </Button>
        </div>
      </li>
    </ul>
  </section>
</template>

<script lang="ts" setup>
import { ref, watch } from "vue";
import { useFileDialog } from "@vueuse/core";
import { ImagePlus, Loader2, Trash2 } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { MAX_GROUP_IMAGES as MAX } from "@/repositories/products";
import ProductThumb from "../ProductThumb.vue";
import type { GalleryImage } from "../images/useImageGallery";

/** The group's pictures: add, drag to reorder, delete, choose the cover. State lives in the gallery composable. */
defineProps<{ images: GalleryImage[]; uploading: boolean; error: string }>();
const emit = defineEmits<{
  add: [files: File[]];
  remove: [index: number];
  move: [from: number, to: number];
  makeCover: [index: number];
}>();

const dragFrom = ref(-1);
const dragOver = ref(-1);
const drop = (to: number) => {
  if (dragFrom.value >= 0) emit("move", dragFrom.value, to);
  dragFrom.value = -1;
  dragOver.value = -1;
};

const { open, files, reset } = useFileDialog({ accept: "image/png,image/jpeg,image/webp,image/gif", multiple: true });
watch(files, (list) => {
  if (!list || list.length === 0) return;
  emit("add", [...list]);
  reset();
});
</script>
