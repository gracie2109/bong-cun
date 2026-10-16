<template>
  <div v-if="admittedRow" class="flex flex-wrap items-center justify-between gap-2 rounded-xl border border-sky-200 bg-sky-50 px-4 py-3 text-sm">
    <p class="font-semibold text-sky-900">
      {{ $t("medical.admit.inWard", { kennel: admittedRow.kennelCode }) }}
    </p>
    <Button size="sm" variant="outline" as-child>
      <router-link :to="{ name: 'medicalWard' }">{{ $t("medical.admit.openWard") }}</router-link>
    </Button>
  </div>
  <div v-else-if="canAdmit" class="flex flex-wrap items-center justify-between gap-2 rounded-xl border bg-white px-4 py-3 text-sm">
    <p class="text-muted-foreground">{{ $t("medical.admit.hint") }}</p>
    <Button size="sm" variant="outline" @click="open = true"><BedDouble class="mr-1 size-4" />{{ $t("medical.admit.button") }}</Button>
  </div>
  <AdmitDialog v-if="canAdmit" v-model:open="open" :visit="visit" />
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { BedDouble } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { useInpatientWard } from "@/queries/inpatient";
import type { MedicalVisitDetail } from "@/types/medicalVisit";
import { todayKey } from "../../../boarding/format";
import AdmitDialog from "./AdmitDialog.vue";

const props = defineProps<{ visit: MedicalVisitDetail; canUpdate: boolean }>();

const open = ref(false);
const ward = useInpatientWard(computed(() => props.visit.branchId), todayKey());
const admittedRow = computed(() => ward.data.value?.rows.find((row) => row.visitId === props.visit.id) ?? null);
const canAdmit = computed(() => props.canUpdate && props.visit.status === "in_progress" && !props.visit.signedAt);
</script>
