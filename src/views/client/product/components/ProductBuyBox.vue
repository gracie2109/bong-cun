<template>
  <div class="space-y-5">
    <div class="space-y-2">
      <p v-if="group.brandName" class="text-xs font-semibold uppercase tracking-wide text-primary">{{ group.brandName }}</p>
      <h1 class="text-2xl font-bold md:text-3xl">{{ group.name }}</h1>
      <p v-if="picked?.sku" class="text-xs text-muted-foreground">{{ $t("client.product.sku") }}: {{ picked.sku }}</p>
    </div>

    <p class="text-3xl font-bold text-primary">{{ priceText }}</p>

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

    <p v-if="stockText" class="text-sm font-medium" :class="stock?.kind === 'out' ? 'text-red-700' : 'text-green-700'">
      {{ stockText }}
    </p>

    <div class="flex items-center gap-3">
      <span class="text-sm font-medium">{{ $t("shop.quantity") }}</span>
      <div class="flex items-center rounded-md border">
        <button type="button" class="grid size-10 place-content-center" :aria-label="$t('shop.less')" @click="addToCart.quantity.value = Math.max(1, addToCart.quantity.value - 1)">
          <Minus class="size-4" />
        </button>
        <span class="w-12 text-center tabular-nums">{{ addToCart.quantity.value }}</span>
        <button type="button" class="grid size-10 place-content-center" :aria-label="$t('shop.more')" @click="addToCart.quantity.value = Math.min(99, addToCart.quantity.value + 1)">
          <Plus class="size-4" />
        </button>
      </div>
    </div>

    <p v-if="!picked" class="text-sm text-muted-foreground">{{ $t("shop.pickVariant") }}</p>
    <div class="flex flex-wrap gap-3">
      <Button class="h-12 flex-1 text-base" :disabled="!canAdd" @click="addToCart.add()">
        <ShoppingBag class="mr-2 size-5" />{{ $t("shop.addToCart") }}
      </Button>
      <Button class="h-12 flex-1 bg-orange-500 text-base hover:bg-orange-600" :disabled="!canAdd" @click="buyNow">
        {{ $t("client.product.buyNow") }}
      </Button>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import { useRouter } from "vue-router";
import { Minus, Plus, ShoppingBag } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import VariantOptions from "@/components/VariantOptions.vue";
import { formatPrice } from "@/lib/utils";
import type { useProductPage } from "@/composables/shop/useProductPage";
import type { ProductGroup } from "@/repositories/products";
import { groupPriceLabel } from "@/utils/shop/catalog";

type Page = ReturnType<typeof useProductPage>;
const props = defineProps<{
  group: ProductGroup;
  choice: Page["choice"];
  addToCart: Page["addToCart"];
  stock: Page["stock"]["value"];
  canAdd: boolean;
}>();

const { t } = useI18n();
const router = useRouter();

const picked = computed(() => props.choice.variant.value);
const priceText = computed(() => {
  const price = props.addToCart.price.value;
  if (picked.value && price !== null) return formatPrice(price) ?? "";
  return groupPriceLabel(props.group, t("client.catalog.from"));
});
const stockText = computed(() => {
  const { stock } = props;
  if (!stock) return "";
  if (stock.kind === "out") return t("client.product.outOfStock");
  if (stock.kind === "low") return t("client.product.lowStock", { count: stock.count });
  return t("client.product.inStock");
});

const buyNow = () => {
  if (props.addToCart.add()) void router.push({ name: "cart" });
};
</script>
