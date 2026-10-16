<template>
  <div class="space-y-2">
    <div class="table-scroll admin-table rounded-xl border">
      <table class="w-full text-sm">
        <thead>
          <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
            <th class="px-3 py-2 font-semibold">{{ $t("products.units.name") }}</th>
            <th class="px-3 py-2 font-semibold">{{ $t("products.units.factor", { unit: baseUnit }) }}</th>
            <th class="px-3 py-2 font-semibold">{{ $t("products.form.barcode") }}</th>
            <th class="px-3 py-2 text-right font-semibold">{{ $t("products.form.price") }}</th>
            <th class="px-3 py-2 text-center font-semibold">{{ $t("products.units.sell") }}</th>
            <th class="px-3 py-2 text-center font-semibold">{{ $t("products.units.purchase") }}</th>
            <th class="px-3 py-2 text-center font-semibold">{{ $t("products.units.active") }}</th>
            <th class="w-10 px-3 py-2" />
          </tr>
        </thead>
        <tbody>
          <tr v-for="(row, index) in rows" :key="row.uid" class="border-t align-top" :class="row.isActive ? '' : 'bg-muted/40'">
            <td class="px-3 py-2">
              <Input v-model="row.name" class="h-8 w-28" />
              <p v-if="submitted && problem(index)" class="text-xs text-red-600">{{ $t(`products.units.problem.${problem(index)}`) }}</p>
            </td>
            <td class="px-3 py-2"><Input v-model="row.factor" class="h-8 w-20 text-right" inputmode="decimal" /></td>
            <td class="px-3 py-2"><Input v-model="row.barcode" class="h-8 w-32" /></td>
            <td class="px-3 py-2">
              <Input
                v-model="row.price"
                class="h-8 w-28 text-right"
                inputmode="numeric"
                :placeholder="money(autoUnitPrice(basePrice, row.factor))"
              />
            </td>
            <td class="px-3 py-2 text-center"><Switch v-model:checked="row.forSale" /></td>
            <td class="px-3 py-2 text-center"><Switch v-model:checked="row.forPurchase" /></td>
            <td class="px-3 py-2 text-center"><Switch v-model:checked="row.isActive" /></td>
            <td class="px-3 py-2">
              <Button type="button" variant="ghost" size="icon" class="size-7 text-muted-foreground" :aria-label="$t('products.units.remove')" @click="rows.splice(index, 1)">
                <X class="size-4" />
              </Button>
            </td>
          </tr>
          <tr v-if="rows.length === 0">
            <td colspan="8" class="px-3 py-6 text-center text-muted-foreground">{{ $t("products.units.empty") }}</td>
          </tr>
        </tbody>
      </table>
    </div>
    <Button type="button" variant="outline" size="sm" @click="rows.push(newUnitRow())">
      <Plus class="mr-1 size-4" />
      {{ $t("products.units.add") }}
    </Button>
  </div>
</template>

<script lang="ts" setup>
import { Plus, X } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Switch } from "@/components/ui/switch";
import { money } from "@/views/admin/pos/format";
import { autoUnitPrice, newUnitRow, unitProblem, type UnitRow } from "./productUnitForm";

const props = defineProps<{ baseUnit: string; basePrice: number; submitted: boolean }>();
const rows = defineModel<UnitRow[]>("rows", { required: true });

const problem = (index: number) => unitProblem(rows.value, index, props.baseUnit);
</script>
