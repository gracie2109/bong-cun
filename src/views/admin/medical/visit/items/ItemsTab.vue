<template>
  <div class="space-y-4">
    <div class="flex flex-wrap items-center justify-between gap-2">
      <p class="text-sm text-muted-foreground">{{ $t("medical.items.hint") }}</p>
      <div class="flex flex-wrap gap-2">
        <Button variant="outline" size="sm" :disabled="visit.items.every((item) => !item.takeHome)" @click="prescriptionOpen = true">
          <Printer class="mr-2 size-4" />
          {{ $t("medical.items.prescription") }}
        </Button>
        <template v-if="canEdit">
          <Button variant="outline" size="sm" @click="serviceOpen = true">
            <Plus class="mr-1 size-4" />{{ $t("medical.items.addService") }}
          </Button>
          <Button size="sm" @click="drugOpen = true">
            <Pill class="mr-1 size-4" />{{ $t("medical.items.addDrug") }}
          </Button>
        </template>
      </div>
    </div>

    <p v-if="visit.items.length === 0" class="rounded-lg border border-dashed p-8 text-center text-sm text-muted-foreground">
      {{ $t("medical.items.empty") }}
    </p>
    <div v-else class="overflow-x-auto rounded-lg border">
      <table class="w-full text-sm">
        <thead>
          <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
            <th class="px-3 py-2 font-semibold">{{ $t("medical.items.name") }}</th>
            <th class="px-3 py-2 text-right font-semibold">{{ $t("medical.items.qty") }}</th>
            <th class="px-3 py-2 text-right font-semibold">{{ $t("medical.items.price") }}</th>
            <th class="px-3 py-2 text-right font-semibold">{{ $t("medical.items.amount") }}</th>
            <th class="px-3 py-2 font-semibold">{{ $t("medical.items.addedBy") }}</th>
            <th class="px-3 py-2" />
          </tr>
        </thead>
        <tbody>
          <ItemRow
            v-for="item in visit.items"
            :key="item.id"
            :item="item"
            :can-edit="canEdit"
            @change-qty="changeQty(item.id, $event)"
            @remove="remove(item.id)"
          />
        </tbody>
        <tfoot>
          <tr class="border-t bg-muted/30">
            <td colspan="3" class="px-3 py-2 text-right font-semibold">{{ $t("medical.items.total") }}</td>
            <td class="whitespace-nowrap px-3 py-2 text-right font-bold">{{ money(total) }}</td>
            <td colspan="2" />
          </tr>
        </tfoot>
      </table>
    </div>

    <AddServiceDialog v-model:open="serviceOpen" :saving="saving" :add="add" />
    <AddDrugDialog v-model:open="drugOpen" :saving="saving" :add="add" :pet-allergies="visit.pet?.allergies ?? null" />
    <PrescriptionDialog v-model:open="prescriptionOpen" :visit-id="visit.id" />
  </div>
</template>

<script lang="ts" setup>
import { toRef } from "vue";
import { Pill, Plus, Printer } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import type { MedicalVisitDetail } from "@/types/medicalVisit";
import { money } from "../../format";
import AddDrugDialog from "./AddDrugDialog.vue";
import AddServiceDialog from "./AddServiceDialog.vue";
import ItemRow from "./ItemRow.vue";
import PrescriptionDialog from "./PrescriptionDialog.vue";
import { useVisitItems } from "./useVisitItems";

const props = defineProps<{ visit: MedicalVisitDetail; canUpdate: boolean }>();

const { canEdit, serviceOpen, drugOpen, prescriptionOpen, total, add, changeQty, remove, saving } = useVisitItems(
  toRef(props, "visit"),
  toRef(props, "canUpdate")
);
</script>
