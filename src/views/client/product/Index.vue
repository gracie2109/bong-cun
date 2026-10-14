<template>
  <div class="container space-y-8 py-6">
    <div v-if="page.status.value === 'loading'" class="grid gap-8 md:grid-cols-2">
      <Skeleton class="aspect-square w-full rounded-xl" />
      <div class="space-y-4"><Skeleton class="h-8 w-3/4" /><Skeleton class="h-10 w-1/3" /><Skeleton class="h-24 w-full" /></div>
    </div>

    <ProductUnavailable
      v-else-if="page.status.value !== 'ready' || !page.group.value"
      :failed="page.status.value === 'error'"
      @retry="page.retry"
    />

    <template v-else>
      <ProductBreadcrumb
        :name="page.group.value.name"
        :category-id="page.group.value.categoryId"
        :category-name="page.group.value.categoryName"
        :parent-name="page.group.value.categoryParentName"
      />
      <div class="grid gap-8 md:grid-cols-2">
        <ShopGroupGallery :images="galleryImages" :preferred="image" />
        <ProductBuyBox
          :group="page.group.value"
          :choice="page.choice"
          :add-to-cart="page.addToCart"
          :stock="page.stock.value"
          :can-add="page.canAdd.value"
        />
      </div>
      <ProductDetails :group="page.group.value" :variant="page.choice.variant.value" />
      <RelatedProducts :groups="page.related.value" />
    </template>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import ShopGroupGallery from "@/components/ShopGroupGallery.vue";
import { Skeleton } from "@/components/ui/skeleton";
import { useProductPage } from "@/composables/shop/useProductPage";
import { groupCover, groupGallery } from "@/utils/shop/catalog";
import ProductBreadcrumb from "./components/ProductBreadcrumb.vue";
import ProductBuyBox from "./components/ProductBuyBox.vue";
import ProductDetails from "./components/ProductDetails.vue";
import ProductUnavailable from "./components/ProductUnavailable.vue";
import RelatedProducts from "./components/RelatedProducts.vue";

const page = useProductPage();

const galleryImages = computed(() => (page.group.value ? groupGallery(page.group.value) : []));
// The picked variant's own photo when it has one.
const image = computed(
  () => page.choice.variant.value?.imageUrl || (page.group.value ? groupCover(page.group.value) : undefined)
);
</script>
