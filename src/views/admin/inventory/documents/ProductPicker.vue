<template>
  <div class="relative">
    <ScanLine class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
    <Input
      v-model="search"
      class="pl-9"
      :placeholder="$t('inventory.documents.addProduct')"
      @keydown.enter.prevent="pickExact"
      @blur="closeSoon"
      @focus="focused = true"
    />
    <ul
      v-if="focused && search.trim()"
      class="absolute z-20 mt-1 max-h-72 w-full overflow-y-auto rounded-lg border bg-white py-1 shadow-lg"
    >
      <li v-if="productsQuery.isFetching.value && results.length === 0" class="px-3 py-2 text-sm text-muted-foreground">
        {{ $t("petCare.common.loading") }}
      </li>
      <li v-else-if="results.length === 0" class="px-3 py-2 text-sm text-muted-foreground">{{ $t("pos.catalog.empty") }}</li>
      <li v-for="product in results" :key="product.id">
        <button
          type="button"
          class="flex w-full items-center justify-between gap-3 px-3 py-2 text-left text-sm hover:bg-muted disabled:opacity-50"
          :disabled="!product.trackStock"
          @mousedown.prevent="pick(product)"
        >
          <span class="min-w-0">
            <span class="block truncate font-medium">{{ product.name }}</span>
            <span class="text-xs text-muted-foreground">
              {{ [product.sku, product.barcode, product.unit].filter(Boolean).join(" · ") }}
            </span>
          </span>
          <span v-if="!product.trackStock" class="shrink-0 text-[11px] text-muted-foreground">
            {{ $t("inventory.documents.untracked") }}
          </span>
        </button>
      </li>
    </ul>
  </div>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { refDebounced } from "@vueuse/core";
import { ScanLine } from "lucide-vue-next";
import { Input } from "@/components/ui/input";
import { supabaseClient } from "@/lib/supabase";
import { useSellableProducts } from "@/queries/products";
import { searchSellableProducts, type Product } from "@/repositories/products";
import { SEARCH_DEBOUNCE_MS } from "@/lib/listing";

const BLUR_CLOSE_MS = 150;

const emit = defineEmits<{ pick: [product: Product] }>();

const search = ref("");
const focused = ref(false);
const debounced = refDebounced(search, SEARCH_DEBOUNCE_MS);
const productsQuery = useSellableProducts(debounced);
const results = computed(() => (debounced.value.trim() ? productsQuery.data.value ?? [] : []));

const pick = (product: Product) => {
  if (!product.trackStock) return;
  emit("pick", product);
  search.value = "";
};

// A barcode scanner types the code and presses Enter before the debounce: look the code up now.
const pickExact = async () => {
  const code = search.value.trim();
  if (!code) return;
  const pool = await searchSellableProducts(supabaseClient(), code);
  const exact = pool.find((product) => product.barcode === code || product.sku === code);
  const match = exact ?? (pool.length === 1 ? pool[0] : undefined);
  if (match) pick(match);
};

const closeSoon = () => setTimeout(() => (focused.value = false), BLUR_CLOSE_MS);
</script>
