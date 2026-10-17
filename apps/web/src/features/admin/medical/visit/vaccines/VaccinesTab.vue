<template>
  <div class="space-y-4">
    <div class="flex flex-wrap items-center justify-between gap-2">
      <p class="text-sm text-muted-foreground">{{ $t("medical.book.visitHint") }}</p>
      <Button v-if="canGive" size="sm" @click="giveOpen = true">
        <Syringe class="mr-1 size-4" />{{ $t("medical.book.give") }}
      </Button>
    </div>

    <VaccineBookList :entries="book" :can-void="canVoid" @void="voiding = $event" />

    <GiveVaccineDialog v-model:open="giveOpen" :visit-id="visit.id" :branch-id="visit.branchId" :book="book" />
    <VoidDoseDialog :open="!!voiding" :busy="voidMutation.isPending.value" @update:open="voiding = null" @confirm="confirmVoid" />
  </div>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { Syringe } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { usePetBook, useVoidVaccine } from "@/features/admin/medical/queries/vaccinations";
import type { MedicalVisitDetail } from "@bongcun/core/medical";
import type { VaccineDose } from "@bongcun/core/medical";
import VaccineBookList from "../../book/VaccineBookList.vue";
import VoidDoseDialog from "../../book/VoidDoseDialog.vue";
import GiveVaccineDialog from "./GiveVaccineDialog.vue";

const props = defineProps<{ visit: MedicalVisitDetail; canUpdate: boolean }>();

const bookQuery = usePetBook(computed(() => props.visit.petId));
const book = computed(() => bookQuery.data.value ?? []);

const canGive = computed(() => props.canUpdate && ["in_progress", "done", "paid"].includes(props.visit.status));
// A shot given in this visit can be struck out while its charge is not on an invoice (the database decides).
const canVoid = (dose: VaccineDose) => props.canUpdate && dose.visitId === props.visit.id;

const giveOpen = ref(false);
const voiding = ref<VaccineDose | null>(null);
const voidMutation = useVoidVaccine();

const confirmVoid = async (reason: string) => {
  if (!voiding.value) return;
  try {
    await voidMutation.mutateAsync({ id: voiding.value.id, reason });
    voiding.value = null;
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
