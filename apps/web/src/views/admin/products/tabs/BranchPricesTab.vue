<template>
  <section class="space-y-3">
    <div>
      <h3 class="font-semibold">{{ $t("products.branchPrices.title") }}</h3>
      <p class="text-xs text-muted-foreground">{{ $t("products.branchPrices.hint") }}</p>
    </div>

    <p v-if="!rows.some((row) => row.id)" class="rounded-lg border border-dashed p-4 text-sm text-muted-foreground">
      {{ $t("products.branchPrices.saveFirst") }}
    </p>
    <div v-else class="table-scroll admin-table rounded-xl border">
      <table class="w-full text-sm">
        <thead>
          <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
            <th class="px-3 py-2 font-semibold">{{ $t("products.variants.variant") }}</th>
            <th class="px-3 py-2 text-right font-semibold">{{ $t("products.branchPrices.general") }}</th>
            <th v-for="branch in branches" :key="branch.id" class="px-3 py-2 text-right font-semibold">{{ branch.name }}</th>
          </tr>
        </thead>
        <tbody>
          <template v-for="row in rows" :key="row.key">
            <tr v-if="row.id" class="border-t align-top">
              <td class="whitespace-nowrap px-3 py-2 font-medium">
                {{ row.options.join(" / ") || $t("products.variants.default") }}
              </td>
              <td class="whitespace-nowrap px-3 py-2 text-right text-muted-foreground">{{ money(parseAmount(row.price)) }}</td>
              <td v-for="branch in branches" :key="branch.id" class="px-3 py-2">
                <Input
                  v-model="cells[cellKey(row.id, branch.id)]"
                  class="h-8 w-28 text-right"
                  inputmode="numeric"
                  :disabled="!canEdit(branch.id)"
                  :title="canEdit(branch.id) ? '' : $t('products.branchPrices.noPermission')"
                  :placeholder="money(parseAmount(row.price))"
                />
              </td>
            </tr>
          </template>
        </tbody>
      </table>
    </div>
    <p v-if="rows.some((row) => !row.id)" class="text-xs text-muted-foreground">{{ $t("products.branchPrices.newVariants") }}</p>
  </section>
</template>

<script lang="ts" setup>
import { Input } from "@/components/ui/input";
import type { Branch } from "@bongcun/supabase/users";
import { money, parseAmount } from "@/views/admin/pos/format";
import type { VariantRow } from "../productVariantForm";
import { cellKey } from "../prices/priceGrid";

/** Branch price of each saved variant; an empty cell keeps the general price. */
defineProps<{
  rows: VariantRow[];
  branches: Branch[];
  cells: Record<string, string>;
  canEdit: (branchId: string) => boolean;
}>();
</script>
