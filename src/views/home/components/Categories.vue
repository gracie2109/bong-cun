<script setup lang="ts">
import Section from "@/components/Section.vue";
import { INTRO_CATEGORIES } from "../constants";
import "vue3-carousel/carousel.css";
import { Carousel, Slide, Pagination, Navigation, type CarouselConfig } from "vue3-carousel";
import { useResizeObserver } from "@vueuse/core";
import { computed, ref, onMounted, watch } from "vue";
import { useProductCategories } from "@/queries/productCategories";

// Top-level categories that have a picture; until there are some, the sample tiles stay.
const categoriesQuery = useProductCategories({ pageIndex: 1, pageSize: 24 }, { rootsOnly: true });
const items = computed(() => {
  const real = (categoriesQuery.data.value?.rows ?? []).flatMap((row) =>
    row.imageUrl ? [{ image: row.imageUrl, label: row.name }] : []
  );
  return real.length > 0 ? real : INTRO_CATEGORIES;
});

const el = ref<HTMLElement | null>(null);
const widthEl = ref<Number>(0);

onMounted(() => {
  if (el.value) {
    widthEl.value = el.value.clientWidth;
  }
});

useResizeObserver(el, (entries) => {
  const entry = entries[0];
  const { width } = entry.contentRect;
  widthEl.value = width;
});

const carouselConfig = ref<Partial<CarouselConfig>>({
  wrapAround: true,
  itemsToShow: 6,
  snapAlign:'start',
  gap: 4
});

watch(widthEl, (newWidth:Number) => {
  carouselConfig.value.itemsToShow = Math.max(Math.floor(+newWidth / 200), 2);
});
</script>

<template>
  <Section class="relative categories slide-container" ref="el">
    <h1
      class="text-center uppercase font-bold text-3xl text-primary md:text-4xl lg:text-4xl sm:text-3xl mb-8"
    >
      Danh mục sản phẩm
    </h1>
    <div class="relative h-full">
      <Carousel v-bind="carouselConfig">
        <Slide
          v-for="(i, j) of items"
          :key="j"
          class="flex-none first:pl-4 last:pr-4 cursor-pointer md:h-[200px] sm:h-[150px]"
        >
          <div
            class="carousel__item grid gap-3 p-3 w-[160px] sm:w-[180px] h-full md:w-[200px] place-content-center bg-[#F7C860] text-white rounded-md snap-start hover:shadow-lg transition-all duration-300 flex flex-col items-center"
          >
            <div class="w-[80px] h-[80px] sm:w-[90px] mx-auto flex-shrink-0">
              <img
                :src="i.image"
                :alt="i.label"
                class="w-full h-full object-cover hover:scale-110 transition-transform duration-300"
              />
            </div>
            <p
              class="text-sm sm:text-sm md:text-base text-center font-medium flex-grow"
            >
              {{ i.label }}
            </p>
          </div>
        </Slide>

        <template #addons>
          <div class="addOns mt-5">
            <Navigation />
            <Pagination />
          </div>
        </template>
      </Carousel>
    </div>
  </Section>
</template>

<style scoped>
.categories {
  @apply relative;
}
.addOns {
  display: none;
}
@media (max-width: 500px) {
  .addOns {
    display: block;
  }
}
:deep(.carousel__pagination) {
  top: 11rem !important;
}
@media (min-width: 900px) {
  .categories {
    top: 8rem;
  }
}
@media (max-width: 899px) {
  .categories {
    top: 12rem;
  }
}
</style>
