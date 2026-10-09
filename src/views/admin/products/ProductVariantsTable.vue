<template>
  <section class="space-y-3">
    <div class="flex flex-wrap items-end justify-between gap-3">
      <div>
        <h3 class="font-semibold">{{ $t("products.variants.title", { n: rows.length }) }}</h3>
        <p class="text-xs text-muted-foreground">{{ $t("products.variants.hint") }}</p>
      </div>
      <div class="flex flex-wrap items-center gap-2">
        <Input v-model="bulk.price" class="w-32" inputmode="numeric" :placeholder="$t('products.variants.bulkPrice')" />
        <Input v-model="bulk.unit" class="w-28" :placeholder="$t('products.variants.bulkUnit')" />
        <Button type="button" variant="outline" size="sm" @click="applyBulk">{{ $t("products.variants.bulk") }}</Button>
      </div>
    </div>

    <div class="table-scroll rounded-xl border">
      <table class="w-full text-sm">
        <thead>
          <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
            <th class="px-3 py-2 font-semibold">{{ $t("products.variants.variant") }}</th>
            <th class="px-3 py-2 font-semibold">{{ $t("products.form.sku") }}</th>
            <th class="px-3 py-2 font-semibold">{{ $t("products.form.barcode") }}</th>
            <th class="px-3 py-2 font-semibold">{{ $t("products.form.unit") }}</th>
            <th class="px-3 py-2 text-right font-semibold">{{ $t("products.form.price") }}</th>
            <th class="px-3 py-2 text-center font-semibold">{{ $t("products.variants.stock") }}</th>
            <th class="px-3 py-2 text-center font-semibold">{{ $t("products.variants.sell") }}</th>
            <th class="px-3 py-2 font-semibold">{{ $t("products.variants.image") }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="row in rows" :key="row.key" class="border-t align-top" :class="row.isActive ? '' : 'bg-muted/40'">
            <td class="whitespace-nowrap px-3 py-2 font-medium">
              {{ row.options.join(" / ") || $t("products.variants.default") }}
              <span v-if="!row.id" class="ml-1 rounded-full bg-amber-50 px-1.5 py-0.5 text-[10px] font-semibold text-amber-700">
                {{ $t("products.variants.new") }}
              </span>
            </td>
            <td class="px-3 py-2"><Input v-model="row.sku" class="h-8 w-28" /></td>
            <td class="px-3 py-2"><Input v-model="row.barcode" class="h-8 w-32" /></td>
            <td class="px-3 py-2">
              <Input v-model="row.unit" class="h-8 w-20" />
              <p v-if="submitted && !row.unit.trim()" class="text-xs text-red-600">{{ $t("petCare.common.required") }}</p>
            </td>
            <td class="px-3 py-2">
              <Input v-model="row.price" class="h-8 w-28 text-right" inputmode="numeric" />
              <p class="mt-0.5 text-right text-[11px] text-muted-foreground">{{ money(parseAmount(row.price)) }}</p>
            </td>
            <td class="px-3 py-2 text-center"><Switch v-model:checked="row.trackStock" /></td>
            <td class="px-3 py-2 text-center"><Switch v-model:checked="row.isActive" /></td>
            <td class="px-3 py-2">
              <UploadFields
                folder-name="products"
                :limit="1"
                :show-control="false"
                size="sm"
                keep-files
                :model-value="toImages(row.imageUrl)"
                @set-images="(list: string[]) => (row.imageUrl = list[0] ?? '')"
              />
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <p v-if="rows.length > MANY_VARIANTS" class="text-xs text-amber-700">
      {{ $t("products.variants.many", { n: rows.length }) }}
    </p>
  </section>
</template>

<script lang="ts" setup>
import UploadFields from "@/components/common/UploadFields.vue";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Switch } from "@/components/ui/switch";
import { money, parseAmount } from "@/views/admin/pos/format";
import { type VariantRow } from "./productVariantForm";

const MANY_VARIANTS = 100;
/** The single-image list the upload box shows. */
const toImages = (url: string) => (url ? [url] : []);

defineProps<{
  /** Whether a save was attempted, which shows the errors. */
  submitted: boolean;
}>();

const rows = defineModel<VariantRow[]>("rows", { required: true });
const bulk = defineModel<{ price: string; unit: string }>("bulk", { required: true });

/** Copies the bulk price and unit onto every row; an empty field leaves that column alone. */
const applyBulk = () => {
  for (const row of rows.value) {
    if (bulk.value.price.trim()) row.price = bulk.value.price;
    if (bulk.value.unit.trim()) row.unit = bulk.value.unit.trim();
  }
};
</script>
