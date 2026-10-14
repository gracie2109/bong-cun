<script lang="ts" setup>
import Banner from "./components/Sliders.vue";
import Services from "./components/Services.vue";
import Categories from "./components/Categories.vue";
import SpaCta from "./components/SpaCta.vue";
import CatalogCard from "@/views/client/catalog/components/CatalogCard.vue";
import { useShopCatalog } from "@/queries/shopCatalog";

// One card per product group; variants are picked in the quick view.
const { groups } = useShopCatalog({ sort: "newest" }, 12);
</script>
<template>
  <div>
    <Banner />
    <div class="container relative">
      <div class="relative">
        <Services />
      </div>

      <div class="relative mb-5">
        <Categories />
      </div>
    </div>

    <div v-if="groups.length > 0" class="mt-[15rem] bg-[#bd994b] pt-5">
      <div class="container py-5">
        <h2 class="mb-8 text-center text-3xl font-bold uppercase text-white md:text-4xl">
          {{ $t("client.home.featured") }}
        </h2>
        <div
          class="product_list custom-scrollbar2 flex snap-x snap-mandatory gap-4 overflow-x-auto pb-4"
        >
          <div v-for="group in groups" :key="group.id">
            <div class="w-[260px] snap-start">
              <CatalogCard :group="group" />
            </div>
          </div>
        </div>
        <div class="mt-4 text-center">
          <RouterLink :to="{ name: 'products' }" class="font-semibold text-white underline">
            {{ $t("client.home.viewAll") }}
          </RouterLink>
        </div>
      </div>
    </div>

    <div :class="{ 'mt-[15rem]': groups.length === 0 }">
      <SpaCta />
    </div>
  </div>
</template>
