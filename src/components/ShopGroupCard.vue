<template>
  <div
    class="group relative flex h-full w-full cursor-pointer flex-col overflow-hidden rounded-md p-3 hover:shadow-xl"
    :class="{ border: showBorder }"
    @click="open = true"
  >
    <div class="relative h-[60%] w-full">
      <img v-if="cover" :src="cover" alt="" class="size-full object-scale-down" />
      <div v-else class="grid size-full place-content-center bg-muted/40">
        <ImageIcon class="size-10 text-muted-foreground" />
      </div>
    </div>
    <div class="mt-2 flex flex-1 flex-col justify-between gap-2">
      <p class="line-clamp-2 text-xl font-semibold">{{ group.name }}</p>
      <div>
        <p v-if="optionHint" class="mb-1 truncate text-sm text-muted-foreground">{{ optionHint }}</p>
        <p class="font-bold text-primary">{{ priceLabel }}</p>
      </div>
    </div>
  </div>

  <Dialog :open="open" @update:open="(value) => (open = value)">
    <DialogContent class="max-h-[90dvh] overflow-y-auto sm:max-w-3xl">
      <div class="grid gap-6 md:grid-cols-2">
        <ShopGroupGallery :images="galleryImages" :preferred="image" />

        <div class="flex flex-col gap-5">
          <DialogHeader class="text-left">
            <DialogTitle class="text-2xl">{{ group.name }}</DialogTitle>
            <DialogDescription v-if="group.desc">{{ group.desc }}</DialogDescription>
          </DialogHeader>

          <p class="text-2xl font-bold text-primary">
            {{ choice.variant.value && addToCart.price.value !== null ? formatPrice(addToCart.price.value) : priceLabel }}
          </p>

          <VariantOptions
            v-if="choice.attributes.value.length > 0"
            :attributes="choice.attributes.value"
            :picks="choice.picks.value"
            :is-available="choice.isAvailable"
            @pick="choice.pick"
          />

          <div v-if="addToCart.unitOptions.value.length > 1" class="flex flex-wrap items-center gap-2">
            <button
              v-for="option in addToCart.unitOptions.value"
              :key="option.id ?? 'base'"
              type="button"
              class="rounded-full border px-3 py-1 text-sm transition-colors"
              :class="addToCart.unitId.value === option.id ? 'border-primary bg-primary/10 font-semibold text-primary' : 'hover:bg-muted'"
              @click="addToCart.unitId.value = option.id"
            >
              {{ option.label }}
            </button>
          </div>

          <div class="flex items-center gap-3">
            <span class="text-sm font-medium">{{ $t("shop.quantity") }}</span>
            <div class="flex items-center rounded-md border">
              <button type="button" class="grid size-9 place-content-center" :aria-label="$t('shop.less')" @click="addToCart.quantity.value = Math.max(1, addToCart.quantity.value - 1)">
                <Minus class="size-4" />
              </button>
              <span class="w-10 text-center tabular-nums">{{ addToCart.quantity.value }}</span>
              <button type="button" class="grid size-9 place-content-center" :aria-label="$t('shop.more')" @click="addToCart.quantity.value = Math.min(99, addToCart.quantity.value + 1)">
                <Plus class="size-4" />
              </button>
            </div>
          </div>

          <p v-if="!choice.variant.value" class="text-sm text-muted-foreground">{{ $t("shop.pickVariant") }}</p>
          <Button class="mt-auto h-12 w-full text-lg" :disabled="!choice.variant.value" @click="add">
            {{ $t("shop.addToCart") }}
          </Button>
        </div>
      </div>
    </DialogContent>
  </Dialog>
</template>

<script lang="ts" setup>
import { computed, ref, toRef, watch } from "vue";
import { Image as ImageIcon, Minus, Plus } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import ShopGroupGallery from "@/components/ShopGroupGallery.vue";
import VariantOptions from "@/components/VariantOptions.vue";
import { useAddToCart } from "@/composables/shop/useAddToCart";
import { useVariantChoice } from "@/composables/useVariantChoice";
import { formatPrice } from "@/lib/utils";
import type { ProductGroup } from "@/repositories/products";

const props = defineProps<{ group: ProductGroup; showBorder?: boolean }>();

const open = ref(false);
const choice = useVariantChoice(toRef(props, "group"));
const addToCart = useAddToCart(choice.variant);

/** The gallery's pictures, or the cover alone for a group saved before galleries. */
const galleryImages = computed(() => {
  const urls = props.group.images.map((item) => item.url);
  return urls.length > 0 ? urls : cover.value ? [cover.value] : [];
});
const cover = computed(() => props.group.imageUrl || props.group.variants.find((item) => item.imageUrl)?.imageUrl);
// The picked variant's own photo when it has one.
const image = computed(() => choice.variant.value?.imageUrl || cover.value);

const priceLabel = computed(() => {
  const { minPrice, maxPrice } = props.group;
  if (minPrice === null) return "";
  return maxPrice !== null && maxPrice > minPrice
    ? `${formatPrice(minPrice)} – ${formatPrice(maxPrice)}`
    : formatPrice(minPrice);
});

const optionHint = computed(() =>
  props.group.attributes
    .filter((attribute) => attribute.values.length > 1)
    .map((attribute) => `${attribute.values.length} ${attribute.name.toLowerCase()}`).join(" · ")
);

watch(open, (value) => {
  if (value) addToCart.reset();
});

const add = () => {
  if (addToCart.add()) open.value = false;
};
</script>
