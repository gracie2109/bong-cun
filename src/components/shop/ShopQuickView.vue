<template>
  <Dialog :open="open" @update:open="(value) => emit('update:open', value)">
    <DialogContent class="max-h-[90dvh] overflow-y-auto sm:max-w-3xl">
      <div class="grid gap-6 md:grid-cols-2">
        <ShopGroupGallery :images="galleryImages" :preferred="image" />

        <div class="flex flex-col gap-5">
          <DialogHeader class="text-left">
            <DialogTitle class="text-2xl">{{ group.name }}</DialogTitle>
            <DialogDescription v-if="group.desc">{{ group.desc }}</DialogDescription>
          </DialogHeader>

          <RouterLink
            :to="{ name: 'product-detail', params: { id: group.id } }"
            class="text-sm font-semibold text-primary underline"
            @click="emit('update:open', false)"
          >
            {{ $t("client.product.viewDetail") }}
          </RouterLink>

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
import { computed, toRef, watch } from "vue";
import { useI18n } from "vue-i18n";
import { Minus, Plus } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import ShopGroupGallery from "@/components/ShopGroupGallery.vue";
import VariantOptions from "@/components/VariantOptions.vue";
import { useAddToCart } from "@/composables/shop/useAddToCart";
import { useVariantChoice } from "@/composables/useVariantChoice";
import { formatPrice } from "@/lib/utils";
import type { ShopGroup } from "@/types/catalog";
import { groupCover, groupGallery, groupPriceLabel } from "@/utils/shop/catalog";

const props = defineProps<{ group: ShopGroup; open: boolean }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const { t } = useI18n();
const choice = useVariantChoice(toRef(props, "group"));
const addToCart = useAddToCart(choice.variant);

const cover = computed(() => groupCover(props.group));
const galleryImages = computed(() => groupGallery(props.group));
// The picked variant's own photo when it has one.
const image = computed(() => choice.variant.value?.imageUrl || cover.value);
const priceLabel = computed(() => groupPriceLabel(props.group, t("client.catalog.from")));

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
