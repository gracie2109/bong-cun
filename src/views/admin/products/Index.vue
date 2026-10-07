<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <Package class="size-4 text-primary" />
      {{ $t("products.title") }}
    </h1>
  </Header>

  <ContentWrap>
    <div class="space-y-5">
      <div class="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 class="text-2xl font-bold">
            {{ $t("products.title") }}
            <span class="text-muted-foreground">({{ total }})</span>
          </h2>
          <p class="text-sm text-muted-foreground">{{ $t("products.subtitle") }}</p>
        </div>
        <Button v-if="canCreate" @click="openForm(null)">
          <Plus class="mr-2 size-4" />
          {{ $t("products.add") }}
        </Button>
      </div>

      <div class="flex flex-wrap items-center gap-3 rounded-xl border bg-white p-3">
        <div class="relative min-w-60 flex-1">
          <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input v-model="search" class="pl-9" :placeholder="$t('products.searchPlaceholder')" />
        </div>
        <label class="flex items-center gap-2 text-sm text-muted-foreground">
          <Switch v-model="showArchived" />
          {{ $t("products.showArchived") }}
        </label>
      </div>

      <div class="overflow-hidden rounded-xl border bg-white">
        <div class="flex items-center justify-between gap-3 border-b bg-muted/40 px-4 py-3">
          <span class="rounded-full bg-primary/10 px-2 py-0.5 text-[11px] font-medium text-primary">
            {{ $t("petCare.common.showing", { count: rows.length, total }) }}
          </span>
          <div class="flex items-center gap-1 text-xs text-muted-foreground">
            <Button variant="ghost" size="icon" class="size-7" :disabled="page.pageIndex <= 1" @click="page.pageIndex -= 1">
              <ChevronLeft class="size-4" />
            </Button>
            <span>{{ $t("petCare.common.pageOf", { page: page.pageIndex, pages: pageCount }) }}</span>
            <Button variant="ghost" size="icon" class="size-7" :disabled="page.pageIndex >= pageCount" @click="page.pageIndex += 1">
              <ChevronRight class="size-4" />
            </Button>
          </div>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
                <th class="px-4 py-3 font-semibold">{{ $t("products.col.product") }}</th>
                <th class="px-4 py-3 font-semibold">{{ $t("products.form.sku") }}</th>
                <th class="px-4 py-3 font-semibold">{{ $t("products.form.barcode") }}</th>
                <th class="px-4 py-3 font-semibold">{{ $t("products.form.unit") }}</th>
                <th class="px-4 py-3 text-right font-semibold">{{ $t("products.form.price") }}</th>
                <th class="px-4 py-3" />
              </tr>
            </thead>
            <tbody>
              <template v-if="listQuery.isPending.value">
                <tr v-for="i in 5" :key="i" class="border-t">
                  <td colspan="6" class="px-4 py-3"><Skeleton class="h-8 w-full" /></td>
                </tr>
              </template>
              <tr v-else-if="rows.length === 0">
                <td colspan="6" class="px-4 py-10 text-center text-muted-foreground">{{ $t("products.empty") }}</td>
              </tr>
              <tr v-for="row in rows" :key="row.id" class="border-t" :class="row.isActive ? '' : 'opacity-60'">
                <td class="px-4 py-3">
                  <p class="flex items-center gap-2 font-semibold">
                    {{ row.name }}
                    <span v-if="!row.isActive" class="rounded-full bg-muted px-2 py-0.5 text-[10px] font-semibold text-muted-foreground">
                      {{ $t("petCare.common.archived") }}
                    </span>
                  </p>
                  <p v-if="row.desc" class="line-clamp-1 text-xs text-muted-foreground">{{ row.desc }}</p>
                </td>
                <td class="px-4 py-3">{{ row.sku ?? "—" }}</td>
                <td class="px-4 py-3 font-mono text-xs">{{ row.barcode ?? "—" }}</td>
                <td class="px-4 py-3">{{ row.unit }}</td>
                <td class="whitespace-nowrap px-4 py-3 text-right font-semibold">{{ money(row.price) }}</td>
                <td class="px-4 py-3 text-right">
                  <DropdownMenu v-if="canUpdate">
                    <DropdownMenuTrigger as-child>
                      <Button variant="ghost" size="icon" class="size-8"><EllipsisVertical class="size-4" /></Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end">
                      <DropdownMenuItem @click="openForm(row)">{{ $t("petCare.common.edit") }}</DropdownMenuItem>
                      <DropdownMenuItem @click="setActive(row, !row.isActive)">
                        {{ row.isActive ? $t("petCare.common.archive") : $t("petCare.common.restore") }}
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <ProductFormSheet v-model:open="formOpen" :product="editing" />
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed, reactive, ref, watch } from "vue";
import { refDebounced } from "@vueuse/core";
import { ChevronLeft, ChevronRight, EllipsisVertical, Package, Plus, Search } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { Switch } from "@/components/ui/switch";
import { usePermission } from "@/composables/usePermission";
import { INITIAL_PAGE_INDEX } from "@/lib/constants";
import { useProductsList, useSetProductActive } from "@/queries/products";
import type { Product, ProductFilter } from "@/repositories/products";
import { ContentWrap, Header } from "@/views/admin/components";
import { money } from "@/views/admin/pos/format";
import ProductFormSheet from "./ProductFormSheet.vue";

const PAGE_SIZE = 20;
const SEARCH_DEBOUNCE_MS = 500;

const { canCreate, canUpdate } = usePermission("products");
const search = ref("");
const showArchived = ref(false);
const page = reactive({ pageIndex: INITIAL_PAGE_INDEX, pageSize: PAGE_SIZE });
const formOpen = ref(false);
const editing = ref<Product | null>(null);
const debouncedSearch = refDebounced(search, SEARCH_DEBOUNCE_MS);

const filter = computed<ProductFilter>(() => ({ search: debouncedSearch.value, includeArchived: showArchived.value }));
const listQuery = useProductsList(page, filter);
const rows = computed(() => listQuery.data.value?.rows ?? []);
const total = computed(() => listQuery.data.value?.total ?? 0);
const pageCount = computed(() => Math.max(1, Math.ceil(total.value / PAGE_SIZE)));
const setActiveMutation = useSetProductActive();

watch([debouncedSearch, showArchived], () => {
  page.pageIndex = INITIAL_PAGE_INDEX;
});

const openForm = (product: Product | null) => {
  editing.value = product;
  formOpen.value = true;
};

const setActive = async (product: Product, isActive: boolean) => {
  try {
    await setActiveMutation.mutateAsync({ id: product.id, isActive });
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
