<template>
  <div class="overflow-x-auto rounded-xl border">
    <table class="w-full text-sm">
      <thead>
        <tr class="bg-muted/40 text-left text-[11px] uppercase tracking-wide text-muted-foreground">
          <th class="px-3 py-2 font-semibold">{{ $t("petCare.species.colLabel") }}</th>
          <th class="w-28 px-3 py-2 font-semibold">{{ $t("petCare.species.colFrom") }}</th>
          <th class="w-28 px-3 py-2 font-semibold">{{ $t("petCare.species.colTo") }}</th>
          <th class="w-12 px-3 py-2"></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="row in rows" :key="row.key" class="border-t">
          <td class="px-3 py-2"><Input v-model="row.label" :readonly="!canUpdate" /></td>
          <td class="px-3 py-2">
            <Input v-model="row.min" :readonly="!canUpdate" type="number" min="0" step="0.1" inputmode="decimal" />
          </td>
          <td class="px-3 py-2">
            <Input
              v-model="row.max"
              :readonly="!canUpdate"
              type="number"
              min="0"
              step="0.1"
              inputmode="decimal"
              :placeholder="$t('petCare.species.unlimited')"
            />
          </td>
          <td class="px-3 py-2 text-right">
            <Button
              v-if="canUpdate"
              type="button"
              variant="ghost"
              size="icon"
              class="size-8"
              :aria-label="$t('petCare.species.removeBracket')"
              @click="emit('remove', row.key)"
            >
              <Trash2 class="size-4" />
            </Button>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script lang="ts" setup>
import { Trash2 } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import type { BracketRow } from "./useBracketRows";

defineProps<{ rows: BracketRow[]; canUpdate: boolean }>();

const emit = defineEmits<{ remove: [key: number] }>();
</script>
