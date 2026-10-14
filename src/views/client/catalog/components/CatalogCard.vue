<template>
  <article
    class="group relative flex h-full cursor-pointer flex-col overflow-hidden rounded-xl border bg-white transition-shadow hover:shadow-lg"
    :class="{ 'opacity-70': !group.inStock }"
    @click="open = true"
  >
    <div class="relative aspect-square w-full bg-muted/30">
      <img v-if="cover" :src="cover" :alt="group.name" loading="lazy" class="size-full object-contain p-2" />
      <div v-else class="grid size-full place-content-center">
        <ImageIcon class="size-10 text-muted-foreground" />
      </div>
      <span
        v-if="!group.inStock"
        class="absolute left-2 top-2 rounded-md bg-red-700 px-2 py-0.5 text-xs font-semibold text-white"
      >
        {{ $t("client.catalog.outOfStock") }}
      </span>
    </div>
    <div class="flex flex-1 flex-col gap-1 p-3">
      <p v-if="group.brandName" class="truncate text-xs font-semibold uppercase text-muted-foreground">
        {{ group.brandName }}
      </p>
      <h3 class="line-clamp-2 min-h-[2.5rem] text-sm font-semibold">
        <RouterLink :to="{ name: 'product-detail', params: { id: group.id } }" class="hover:text-primary" @click.stop>
          {{ group.name }}
        </RouterLink>
      </h3>
      <p v-if="optionHint" class="truncate text-xs text-muted-foreground">{{ optionHint }}</p>
      <div class="mt-auto flex items-end justify-between gap-2 pt-2">
        <p class="font-bold text-primary">{{ priceLabel }}</p>
        <Button size="icon" variant="outline" class="size-9" :aria-label="$t('shop.addToCart')" :disabled="!group.inStock">
          <ShoppingBag class="size-4" />
        </Button>
      </div>
    </div>
  </article>
  <ShopQuickView v-model:open="open" :group="group" />
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { useI18n } from "vue-i18n";
import { Image as ImageIcon, ShoppingBag } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import ShopQuickView from "@/components/shop/ShopQuickView.vue";
import type { ShopGroup } from "@/types/catalog";
import { groupCover, groupOptionHint, groupPriceLabel } from "@/utils/shop/catalog";

const props = defineProps<{ group: ShopGroup }>();
const { t } = useI18n();

const open = ref(false);
const cover = computed(() => groupCover(props.group));
const priceLabel = computed(() => groupPriceLabel(props.group, t("client.catalog.from")));
const optionHint = computed(() => groupOptionHint(props.group));
</script>
