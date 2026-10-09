<template>
  <div class="admin-table overflow-x-auto">
    <table class="w-full text-sm">
      <thead>
        <tr class="border-b text-left text-[11px] uppercase tracking-wide text-muted-foreground">
          <th class="py-2 pr-2 font-semibold">{{ $t("products.col.product") }}</th>
          <th class="py-2 pr-2 font-semibold">{{ $t("inventory.lots.lotNo") }}</th>
          <th class="py-2 pr-2 font-semibold">{{ $t("inventory.lots.expiry") }}</th>
          <template v-if="type === 'count'">
            <th class="py-2 pr-2 text-right font-semibold">{{ $t("inventory.documents.systemQty") }}</th>
            <th class="py-2 pr-2 text-right font-semibold">{{ $t("inventory.documents.countedQty") }}</th>
            <th class="py-2 pr-2 text-right font-semibold">{{ $t("inventory.documents.difference") }}</th>
          </template>
          <template v-else>
            <th class="py-2 pr-2 text-right font-semibold">{{ $t("inventory.movements.qty") }}</th>
            <th class="py-2 pr-2 text-right font-semibold">{{ $t("inventory.lots.unitCost") }}</th>
            <th class="py-2 pr-2 text-right font-semibold">{{ $t("pos.invoices.amount") }}</th>
          </template>
          <th v-if="editable" class="py-2" />
        </tr>
      </thead>
      <tbody>
        <tr v-for="line in lines" :key="line.key" class="border-b align-top last:border-0">
          <td class="py-2 pr-2">
            <p class="font-medium">{{ line.productName }}</p>
            <p class="text-xs text-muted-foreground">{{ line.unit }}</p>
          </td>

          <!-- lot -->
          <td class="py-2 pr-2">
            <Input v-if="editable && type === 'receipt'" v-model="line.lotNo" class="h-8 w-32" :placeholder="$t('inventory.lots.noLot')" />
            <Select
              v-else-if="editable && type === 'writeoff'"
              :model-value="line.lotId ?? undefined"
              @update:model-value="(value) => pickLot(line, String(value))"
            >
              <SelectTrigger class="h-8 w-44" :class="submitted && !line.lotId ? 'border-red-500' : ''">
                <SelectValue :placeholder="$t('inventory.documents.pickLot')" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem v-for="lot in line.lotOptions" :key="lot.id" :value="lot.id">
                  {{ lot.lotNo || $t("inventory.lots.noLot") }} · {{ lot.expiryDate ? day(lot.expiryDate) : $t("inventory.lots.noExpiry") }} · {{ qty(lot.qtyOnHand) }}
                </SelectItem>
              </SelectContent>
            </Select>
            <span v-else>{{ line.lotNo || $t("inventory.lots.noLot") }}</span>
          </td>

          <!-- expiry -->
          <td class="py-2 pr-2">
            <Input v-if="editable && type === 'receipt'" v-model="line.expiryDate" type="date" class="h-8 w-40" />
            <span v-else-if="line.expiryDate" :class="isExpired(line.expiryDate) ? 'font-semibold text-red-600' : ''">{{ day(line.expiryDate) }}</span>
            <span v-else class="text-muted-foreground">{{ $t("inventory.lots.noExpiry") }}</span>
          </td>

          <template v-if="type === 'count'">
            <td class="py-2 pr-2 text-right text-muted-foreground">{{ line.systemQty === null ? "—" : qty(line.systemQty) }}</td>
            <td class="py-2 pr-2 text-right">
              <Input
                v-if="editable"
                v-model="line.countedQty"
                inputmode="decimal"
                class="ml-auto h-8 w-24 text-right"
                :class="submitted && !validCounted(line) ? 'border-red-500' : ''"
              />
              <span v-else class="font-semibold">{{ line.countedQty }}</span>
            </td>
            <td class="py-2 pr-2 text-right font-semibold" :class="diffTone(countDiff(line))">
              {{ countDiff(line) === null ? "—" : (countDiff(line) ?? 0) > 0 ? `+${qty(countDiff(line))}` : qty(countDiff(line)) }}
            </td>
          </template>
          <template v-else>
            <td class="py-2 pr-2 text-right">
              <Input
                v-if="editable"
                v-model="line.qty"
                inputmode="decimal"
                class="ml-auto h-8 w-24 text-right"
                :class="submitted && !validQty(type, line) ? 'border-red-500' : ''"
              />
              <span v-else class="font-semibold">{{ line.qty }}</span>
              <p v-if="editable && type === 'writeoff' && selectedLot(line)" class="mt-1 text-[11px] text-muted-foreground">
                {{ $t("inventory.documents.lotHolds", { n: qty(selectedLot(line)?.qtyOnHand) }) }}
              </p>
            </td>
            <td class="py-2 pr-2 text-right">
              <Input
                v-if="editable && type === 'receipt'"
                v-model="line.unitCost"
                inputmode="numeric"
                class="ml-auto h-8 w-28 text-right"
              />
              <span v-else class="text-muted-foreground">{{ money(lineCost(type, line)) }}</span>
            </td>
            <td class="whitespace-nowrap py-2 pr-2 text-right font-medium">{{ money(lineAmount(type, line)) }}</td>
          </template>

          <td v-if="editable" class="py-2 text-right">
            <Button variant="ghost" size="icon" class="size-8 text-muted-foreground" :aria-label="$t('pos.cart.remove')" @click="removeLine(line.key)">
              <X class="size-4" />
            </Button>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script lang="ts" setup>
import { X } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { isExpired, type DocType } from "@/repositories/inventory";
import { money } from "@/views/admin/pos/format";
import { day, qty } from "../format";
import {
  countDiff,
  diffTone,
  lineAmount,
  lineCost,
  pickLot,
  selectedLot,
  validCounted,
  validQty,
  type EditLine,
} from "./documentLines";

defineProps<{
  type: DocType;
  editable: boolean;
  /** Whether a save was attempted, which marks invalid fields. */
  submitted: boolean;
}>();

const lines = defineModel<EditLine[]>("lines", { required: true });

const removeLine = (key: string) => {
  lines.value = lines.value.filter((line) => line.key !== key);
};
</script>
