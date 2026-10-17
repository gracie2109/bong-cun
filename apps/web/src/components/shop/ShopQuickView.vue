<template>
  <Dialog :open="open" @update:open="(value) => emit('update:open', value)">
    <DialogContent class="max-h-[90dvh] w-[calc(100%-2rem)] overflow-y-auto rounded-3xl p-5 sm:max-w-3xl sm:p-6">
      <div class="grid gap-6 md:grid-cols-2">
        <ShopGroupGallery :images="galleryImages" :preferred="image" :alt="group.name" />

        <div class="flex flex-col gap-5">
          <DialogHeader class="space-y-2 text-left">
            <p v-if="group.brandName" class="shop-eyebrow">{{ group.brandName }}</p>
            <DialogTitle class="text-2xl font-bold leading-tight tracking-tight">{{ group.name }}</DialogTitle>
            <DialogDescription v-if="group.desc" class="line-clamp-3">{{ group.desc }}</DialogDescription>
          </DialogHeader>

          <PriceDisplay size="lg" :amount="choice.variant.value ? addToCart.price.value : group.minPrice" :from="!choice.variant.value && hasRange" />

          <VariantOptions
            v-if="choice.attributes.value.length > 0"
            pill
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
              class="min-h-10 rounded-full border px-4 text-sm transition-colors"
              :class="addToCart.unitId.value === option.id ? 'border-foreground bg-foreground font-semibold text-white' : 'bg-white hover:border-foreground/50'"
              :aria-pressed="addToCart.unitId.value === option.id"
              @click="addToCart.unitId.value = option.id"
            >
              {{ option.label }}
            </button>
          </div>

          <p v-if="!choice.variant.value" class="rounded-xl bg-accent px-4 py-3 text-sm text-accent-foreground">{{ $t("shop.pickVariant") }}</p>
          <div class="mt-auto flex flex-wrap items-center gap-3">
            <QuantityStepper v-model="addToCart.quantity.value" />
            <Button class="h-12 min-w-[160px] flex-1 rounded-full text-base" :disabled="!choice.variant.value" @click="add">
              <ShoppingBag class="mr-2 size-5" />{{ $t("shop.addToCart") }}
            </Button>
          </div>
          <RouterLink
            :to="{ name: 'product-detail', params: { id: group.id } }"
            class="inline-flex items-center gap-1 text-sm font-semibold text-primary hover:underline"
            @click="emit('update:open', false)"
          >
            {{ $t("client.product.viewDetail") }}<ArrowRight class="size-4" />
          </RouterLink>
        </div>
      </div>
    </DialogContent>
  </Dialog>
</template>

<script lang="ts" setup>
import { computed, toRef, watch } from "vue";
import { ArrowRight, ShoppingBag } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import ShopGroupGallery from "@/components/ShopGroupGallery.vue";
import VariantOptions from "@/components/VariantOptions.vue";
import { useAddToCart } from "@/features/shop/cart/composables/useAddToCart";
import { useVariantChoice } from "@/composables/useVariantChoice";
import type { ShopGroup } from "@bongcun/core/shop";
import { groupCover, groupGallery, groupHasPriceRange } from "@/utils/shop/catalog";
import PriceDisplay from "./PriceDisplay.vue";
import QuantityStepper from "./QuantityStepper.vue";

const props = defineProps<{ group: ShopGroup; open: boolean }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const choice = useVariantChoice(toRef(props, "group"));
const addToCart = useAddToCart(choice.variant);

const cover = computed(() => groupCover(props.group));
const galleryImages = computed(() => groupGallery(props.group));
// The picked variant's own photo when it has one.
const image = computed(() => choice.variant.value?.imageUrl || cover.value);
const hasRange = computed(() => groupHasPriceRange(props.group));

watch(
  () => props.open,
  (value) => {
    if (value) addToCart.reset();
  }
);

const add = () => {
  if (addToCart.add()) emit("update:open", false);
};
</script>
