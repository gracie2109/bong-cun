<template>
  <RouterLink :to="{ name: 'products', query: { category: category.id } }" class="group block">
    <span class="relative block aspect-[4/3] overflow-hidden rounded-2xl bg-white ring-1 ring-border/70 transition-shadow duration-300 group-hover:shadow-lift">
      <img
        v-if="category.imageUrl"
        :src="category.imageUrl"
        alt=""
        loading="lazy"
        decoding="async"
        class="size-full object-contain p-[10%] transition-transform duration-500 ease-out-quart group-hover:scale-[1.05]"
      />
      <span v-else class="grid size-full place-content-center bg-brand-soft text-brand/50"><PawMark class="size-12" /></span>
    </span>
    <span class="mt-3 flex items-start justify-between gap-2">
      <span class="min-w-0">
        <span class="block font-semibold leading-snug group-hover:text-primary">{{ category.name }}</span>
        <span v-if="category.productCount > 0" class="block text-sm text-muted-foreground">
          {{ $t("client.home.categories.count", { n: category.productCount }) }}
        </span>
      </span>
      <ArrowUpRight class="mt-0.5 size-4 shrink-0 text-muted-foreground transition-transform duration-200 group-hover:-translate-y-0.5 group-hover:translate-x-0.5 group-hover:text-primary" />
    </span>
  </RouterLink>
</template>

<script lang="ts" setup>
import { ArrowUpRight } from "lucide-vue-next";
import PawMark from "@/components/shop/PawMark.vue";
import type { ProductCategory } from "@/repositories/productCategories";

defineProps<{ category: Pick<ProductCategory, "id" | "name" | "imageUrl" | "productCount"> }>();
</script>
