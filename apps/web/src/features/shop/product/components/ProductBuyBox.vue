<template>
  <div class="lg:pt-2">
    <RouterLink
      v-if="group.brandName && group.brandId"
      :to="{ name: 'products', query: { brand: group.brandId } }"
      class="shop-eyebrow hover:underline"
    >
      {{ group.brandName }}
    </RouterLink>
    <h1 class="shop-display mt-2 text-[28px] leading-tight md:text-4xl">{{ group.name }}</h1>
    <p v-if="picked?.sku" class="mt-2 text-sm text-muted-foreground">{{ $t("client.product.sku") }}: {{ picked.sku }}</p>

    <div class="mt-5 flex flex-wrap items-center gap-x-4 gap-y-2">
      <PriceDisplay size="lg" :amount="price" :from="!picked && hasRange" />
      <StockBadge v-if="stock" :kind="stock.kind">{{ stockText }}</StockBadge>
    </div>

    <div class="mt-6 space-y-5 border-t pt-6">
      <VariantOptions
        v-if="choice.attributes.value.length > 0"
        pill
        :attributes="choice.attributes.value"
        :picks="choice.picks.value"
        :is-available="choice.isAvailable"
        @pick="choice.pick"
      />

      <div v-if="addToCart.unitOptions.value.length > 1">
        <p class="mb-1.5 text-sm font-medium">{{ $t("client.product.unit") }}</p>
        <div class="flex flex-wrap gap-2">
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
      </div>

      <p v-if="!picked" class="rounded-xl bg-accent px-4 py-3 text-sm text-accent-foreground">{{ $t("shop.pickVariant") }}</p>

      <div class="flex flex-wrap items-center gap-3">
        <QuantityStepper v-model="addToCart.quantity.value" />
        <Button class="h-12 min-w-[180px] flex-1 rounded-full text-base" :disabled="!canAdd" @click="addToCart.add()">
          <ShoppingBag class="mr-2 size-5" />{{ $t("shop.addToCart") }}
        </Button>
      </div>
      <Button
        variant="outline"
        class="h-12 w-full rounded-full border-foreground text-base hover:bg-foreground hover:text-white"
        :disabled="!canAdd"
        @click="emit('buyNow')"
      >
        {{ $t("client.product.buyNow") }}
      </Button>
    </div>

    <DeliveryInfo class="mt-6" :in-store-only="picked?.shipPolicy === 'in_store_only'" />
  </div>
</template>

<script lang="ts" setup>
import { groupHasPriceRange } from "@/utils/shop/catalog";
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import { ShoppingBag } from "lucide-vue-next";
import PriceDisplay from "@/components/shop/PriceDisplay.vue";
import QuantityStepper from "@/components/shop/QuantityStepper.vue";
import StockBadge from "@/components/shop/StockBadge.vue";
import { Button } from "@/components/ui/button";
import VariantOptions from "@/components/VariantOptions.vue";
import type { useProductPage } from "@/composables/shop/useProductPage";
import type { ProductGroup } from "@bongcun/supabase/products";
import DeliveryInfo from "./DeliveryInfo.vue";

type Page = ReturnType<typeof useProductPage>;
const props = defineProps<{
  group: ProductGroup;
  choice: Page["choice"];
  addToCart: Page["addToCart"];
  stock: Page["stock"]["value"];
  canAdd: boolean;
}>();
const emit = defineEmits<{ buyNow: [] }>();

const { t } = useI18n();

const picked = computed(() => props.choice.variant.value);
const hasRange = computed(() => groupHasPriceRange(props.group));
const price = computed(() => (picked.value ? props.addToCart.price.value : props.group.minPrice));
const stockText = computed(() => {
  const { stock } = props;
  if (!stock) return "";
  if (stock.kind === "out") return t("client.product.outOfStock");
  if (stock.kind === "low") return t("client.product.lowStock", { count: stock.count });
  return t("client.product.inStock");
});
</script>
