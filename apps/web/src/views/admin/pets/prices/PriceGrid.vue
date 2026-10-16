<template>
  <div class="overflow-hidden rounded-xl border bg-white">
    <p class="border-b bg-muted/40 px-4 py-3 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
      {{ $t("petCare.prices.weightRows") }}
    </p>
    <div class="table-scroll admin-table">
      <table class="w-full text-sm">
        <thead>
          <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
            <th class="sticky left-0 bg-white px-4 py-3 font-semibold">{{ $t("petCare.prices.service") }}</th>
            <th v-for="bracket in brackets" :key="bracket.id" class="px-2 py-3 font-semibold">
              {{ bracket.label }}
            </th>
            <th class="px-2 py-3"></th>
          </tr>
        </thead>
        <tbody>
          <template v-if="loading">
            <tr v-for="i in 3" :key="i" class="border-t">
              <td :colspan="brackets.length + 2" class="px-4 py-3"><Skeleton class="h-10 w-full" /></td>
            </tr>
          </template>
          <tr
            v-for="service in services"
            :key="service.id"
            class="border-t"
            :class="service.id === highlightServiceId ? 'bg-primary/5' : ''"
          >
            <td class="sticky left-0 bg-inherit px-4 py-2 font-medium">{{ service.name }}</td>
            <td v-for="bracket in brackets" :key="bracket.id" class="px-2 py-2">
              <Input
                :model-value="cellValue(service.id, bracket.id)"
                :readonly="!canUpdate"
                type="number"
                min="0"
                step="1000"
                inputmode="numeric"
                class="h-9 w-28"
                :class="[
                  isEdited(service.id, bracket.id) ? 'border-primary' : '',
                  cellValue(service.id, bracket.id) === '' ? 'border-dashed border-amber-400' : '',
                ]"
                :placeholder="placeholderOf(service.id, bracket.id)"
                :aria-label="`${service.name} - ${bracket.label}`"
                @update:model-value="emit('setCell', service.id, bracket.id, String($event ?? ''))"
              />
            </td>
            <td class="whitespace-nowrap px-2 py-2 text-right">
              <template v-if="canUpdate">
                <Button type="button" variant="ghost" size="sm" @click="emit('fillRow', service.id)">
                  {{ $t("petCare.prices.fillRow") }}
                </Button>
                <Button type="button" variant="ghost" size="sm" @click="emit('clearRow', service.id)">
                  {{ $t("petCare.prices.clearRow") }}
                </Button>
              </template>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import type { WeightBracket } from "@/repositories/weightBrackets";

defineProps<{
  /** Rows to show. */
  services: { id: string; name: string }[];
  brackets: WeightBracket[];
  loading: boolean;
  canUpdate: boolean;
  /** Row to highlight, when arriving from a link to one service. */
  highlightServiceId?: string;
  cellValue: (serviceId: string, bracketId: string) => string;
  isEdited: (serviceId: string, bracketId: string) => boolean;
  placeholderOf: (serviceId: string, bracketId: string) => string;
}>();

const emit = defineEmits<{
  setCell: [serviceId: string, bracketId: string, value: string];
  fillRow: [serviceId: string];
  clearRow: [serviceId: string];
}>();
</script>
