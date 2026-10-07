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
        <button
          v-for="item in items"
          :key="item.id"
          type="button"
          class="flex min-h-20 flex-col justify-between rounded-lg border p-3 text-left transition-colors hover:border-primary hover:bg-primary/5"
          @click="emit('add', item)"
        >
          <span class="line-clamp-2 text-sm font-semibold">{{ item.name }}</span>
          <span class="mt-1 flex items-end justify-between gap-2">
            <span class="truncate text-[11px] text-muted-foreground">{{ item.hint }}</span>
            <span class="whitespace-nowrap text-sm font-bold text-primary">
              {{ item.price === null ? $t("pos.catalog.byWeight") : money(item.price) }}
            </span>
          </span>
        </button>
      </div>
    </div>
  </section>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { refDebounced } from "@vueuse/core";
import { Layers2, Package, ScanLine, Scissors, Search } from "lucide-vue-next";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { fold } from "@/views/admin/settings/rbac";
import { useAllPetServices } from "@/queries/petServices";
import { useSellableCombos } from "@/queries/pos";
import { useSellableProducts } from "@/queries/products";
import { supabaseClient } from "@/lib/supabase";
import type { LineType } from "@/repositories/pos";
import { searchSellableProducts, type Product } from "@/repositories/products";
import { money } from "../format";

/** One tile; `price` is null for a by-weight service (priced once a pet is picked). */
export type CatalogItem = {
  type: LineType;
  id: string;
  name: string;
  price: number | null;
  unit: string | null;
  hint: string;
  barcode?: string | null;
  sku?: string | null;
};

const SEARCH_DEBOUNCE_MS = 500;
const TABS = [
  { value: "product", label: "pos.catalog.products", icon: Package },
  { value: "service", label: "pos.catalog.services", icon: Scissors },
  { value: "combo", label: "pos.catalog.combos", icon: Layers2 },
] as const;

const emit = defineEmits<{ add: [item: CatalogItem] }>();

const kind = ref<LineType>("product");
const search = ref("");
const debounced = refDebounced(search, SEARCH_DEBOUNCE_MS);

const productsQuery = useSellableProducts(debounced);
const servicesQuery = useAllPetServices();
const combosQuery = useSellableCombos();

const toProductItem = (product: Product): CatalogItem => ({
  type: "product",
  id: product.id,
  name: product.name,
  price: product.price,
  unit: product.unit,
  hint: [product.sku, product.unit].filter(Boolean).join(" · "),
  barcode: product.barcode,
  sku: product.sku,
});

const matches = (name: string) => fold(name).includes(fold(search.value));

const items = computed<CatalogItem[]>(() => {
  if (kind.value === "product") {
    return (productsQuery.data.value ?? []).map(toProductItem);
  }
  if (kind.value === "service") {
    return (servicesQuery.data.value ?? [])
      .filter((service) => matches(service.name))
      .map((service) => ({
        type: "service",
        id: service.id,
        name: service.name,
        price: service.type === "by_weight" ? null : service.generalPrice ?? 0,
        unit: null,
        hint: service.species.map((item) => item.name).join(", "),
      }));
  }
  return (combosQuery.data.value ?? [])
    .filter((combo) => matches(combo.name))
    .map((combo) => ({ type: "combo", id: combo.id, name: combo.name, price: combo.price, unit: null, hint: "" }));
});

const loading = computed(() => {
  if (kind.value === "product") return productsQuery.isPending.value;
  if (kind.value === "service") return servicesQuery.isPending.value;
  return combosQuery.isPending.value;
});

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
  if (!pick) return;
  emit("add", pick);
  search.value = "";
};
</script>
