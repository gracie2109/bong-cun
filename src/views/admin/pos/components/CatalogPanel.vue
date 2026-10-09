<template>
  <section class="flex min-h-0 flex-col rounded-xl border bg-white">
    <div class="space-y-3 border-b p-3">
      <div class="flex gap-1 rounded-lg bg-muted/60 p-1">
        <button
          v-for="tab in TABS"
          :key="tab.value"
          type="button"
          class="flex flex-1 items-center justify-center gap-2 rounded-md px-3 py-1.5 text-sm font-semibold transition-colors"
          :class="kind === tab.value ? 'bg-white text-primary shadow-sm' : 'text-muted-foreground hover:text-foreground'"
          :aria-pressed="kind === tab.value"
          @click="kind = tab.value"
        >
          <component :is="tab.icon" class="size-4" />
          {{ $t(tab.label) }}
        </button>
      </div>
      <div class="relative">
        <ScanLine v-if="kind === 'product'" class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
        <Search v-else class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
        <Input
          v-model="search"
          class="pl-9"
          :placeholder="$t(kind === 'product' ? 'pos.catalog.scanPlaceholder' : 'pos.catalog.searchPlaceholder')"
          @keydown.enter.prevent="addExactMatch"
        />
      </div>
    </div>

    <div class="min-h-0 flex-1 overflow-y-auto p-3">
      <div v-if="loading" class="grid grid-cols-2 gap-2 xl:grid-cols-3">
        <Skeleton v-for="i in 6" :key="i" class="h-20 w-full" />
      </div>
      <p v-else-if="items.length === 0" class="py-10 text-center text-sm text-muted-foreground">
        {{ $t(kind === "product" ? "pos.catalog.noProducts" : "pos.catalog.empty") }}
      </p>
      <div v-else class="grid grid-cols-2 gap-2 xl:grid-cols-3">
        <CatalogTile v-for="item in items" :key="item.id" :item="item" :stock="stockOf(item)" @choose="choose(item)" />
      </div>
    </div>

    <VariantDialog
      :group-id="openGroup?.groupId"
      :title="openGroup?.name ?? ''"
      :branch-id="branchId"
      @close="openGroup = null"
      @pick="(variant) => emit('add', fromVariant(variant))"
    />
  </section>
</template>

<script lang="ts" setup>
import { ref } from "vue";
import { refDebounced } from "@vueuse/core";
import { ScanLine, Search } from "lucide-vue-next";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { SEARCH_DEBOUNCE_MS } from "@/lib/listing";
import { supabaseClient } from "@/lib/supabase";
import type { LineType } from "@/repositories/pos";
import type { ProductVariant } from "@/repositories/products";
import { searchSellableProducts } from "@/repositories/products";
import { CATALOG_TABS as TABS, toProductItem, type CatalogItem } from "../catalog";
import { useCatalogItems } from "../useCatalogItems";
import CatalogTile from "./CatalogTile.vue";
import VariantDialog from "./VariantDialog.vue";

const props = defineProps<{ branchId: string | undefined }>();
const emit = defineEmits<{ add: [item: CatalogItem] }>();

const kind = ref<LineType>("product");
const search = ref("");
const debounced = refDebounced(search, SEARCH_DEBOUNCE_MS);

const { items, loading, stockOf } = useCatalogItems(kind, search, debounced, () => props.branchId);

const fromVariant = (variant: ProductVariant): CatalogItem => toProductItem(variant);

const openGroup = ref<CatalogItem | null>(null);
const choose = (item: CatalogItem) => {
  if (item.groupId) openGroup.value = item;
  else emit("add", item);
};

// A barcode scanner types the code and presses Enter, faster than the search debounce, so the
// code is looked up right away: the exact barcode or SKU, else the only result.
const addExactMatch = async () => {
  const code = search.value.trim();
  if (!code) return;
  const pool =
    kind.value === "product"
      ? (await searchSellableProducts(supabaseClient(), code)).map(toProductItem)
      : items.value;
  const exact = pool.find((item) => item.barcode === code || item.sku === code);
  const pick = exact ?? (pool.length === 1 ? pool[0] : undefined);
  if (!pick || stockOf(pick) === 0) return;
  emit("add", pick);
  search.value = "";
};
</script>
