<template>
  <div class="shop-container pb-24 pt-5 md:pt-8 lg:pb-0">
    <div v-if="page.status.value === 'loading'" class="grid gap-8 lg:grid-cols-[1.1fr_1fr] lg:gap-14" aria-hidden="true">
      <div class="shop-skeleton aspect-square rounded-3xl" />
      <div class="space-y-4 pt-4">
        <div class="shop-skeleton h-4 w-24 rounded-full" />
        <div class="shop-skeleton h-9 w-4/5 rounded-full" />
        <div class="shop-skeleton h-8 w-40 rounded-full" />
        <div class="shop-skeleton h-24 w-full rounded-2xl" />
      </div>
    </div>

    <EmptyState
      v-else-if="page.status.value !== 'ready' || !page.group.value"
      :tone="page.status.value === 'error' ? 'error' : 'empty'"
      :title="$t(page.status.value === 'error' ? 'client.catalog.error' : 'client.product.discontinued')"
      :text="$t(page.status.value === 'error' ? 'client.catalog.errorHint' : 'client.product.discontinuedHint')"
    >
      <Button v-if="page.status.value === 'error'" class="h-11 rounded-full px-6" @click="page.retry">{{ $t("client.catalog.retry") }}</Button>
      <Button v-else as-child class="h-11 rounded-full px-6">
        <RouterLink :to="{ name: 'products' }">{{ $t("client.product.browse") }}</RouterLink>
      </Button>
    </EmptyState>

    <template v-else>
      <ProductBreadcrumb
        :name="page.group.value.name"
        :category-id="page.group.value.categoryId"
        :category-name="page.group.value.categoryName"
        :parent-name="page.group.value.categoryParentName"
      />
      <div class="mt-5 grid gap-8 lg:grid-cols-[1.1fr_1fr] lg:gap-14">
        <ShopGroupGallery class="lg:sticky lg:top-28 lg:self-start" :images="galleryImages" :preferred="image" :alt="page.group.value.name" />
        <ProductBuyBox
          :group="page.group.value"
          :choice="page.choice"
          :add-to-cart="page.addToCart"
          :stock="page.stock.value"
          :can-add="page.canAdd.value"
          @buy-now="buyNow"
        />
      </div>
      <ProductDetails :group="page.group.value" :variant="page.choice.variant.value" />
      <RelatedProducts :groups="page.related.value" />
      <MobileBuyBar
        :price="page.addToCart.price.value"
        :group="page.group.value"
        :picked="Boolean(page.choice.variant.value)"
        :can-add="page.canAdd.value"
        @add="page.addToCart.add()"
      />
    </template>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useRouter } from "vue-router";
import ShopGroupGallery from "@/components/ShopGroupGallery.vue";
import EmptyState from "@/components/shop/EmptyState.vue";
import { Button } from "@/components/ui/button";
import { useProductPage } from "@/composables/shop/useProductPage";
import { groupCover, groupGallery } from "@/utils/shop/catalog";
import MobileBuyBar from "./components/MobileBuyBar.vue";
import ProductBreadcrumb from "./components/ProductBreadcrumb.vue";
import ProductBuyBox from "./components/ProductBuyBox.vue";
import ProductDetails from "./components/ProductDetails.vue";
import RelatedProducts from "./components/RelatedProducts.vue";

const page = useProductPage();
const router = useRouter();

const galleryImages = computed(() => (page.group.value ? groupGallery(page.group.value) : []));
// The picked variant's own photo when it has one.
const image = computed(
  () => page.choice.variant.value?.imageUrl || (page.group.value ? groupCover(page.group.value) : undefined)
);

const buyNow = () => {
  if (page.addToCart.add()) void router.push({ name: "cart" });
};
</script>
