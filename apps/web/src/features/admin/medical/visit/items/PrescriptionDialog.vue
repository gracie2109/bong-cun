<template>
  <AppDialog
    :open="open"
    :title="$t('medical.rx.title')"
    :description="$t('medical.rx.desc')"
    :ok-text="$t('medical.rx.print')"
    :ok-disabled="!rx"
    size="xl"
    @update:open="emit('update:open', $event)"
    @ok="print"
  >
    <p v-if="rxQuery.isPending.value" class="p-6 text-center text-sm text-muted-foreground">{{ $t("petCare.common.loading") }}</p>
    <div v-else-if="rx" class="rounded-lg border">
      <PrescriptionSheet :rx="rx" />
    </div>
  </AppDialog>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import { useMedicalPrescription } from "@/features/admin/medical/queries/medicalVisits";
import PrescriptionSheet from "./PrescriptionSheet.vue";

const props = defineProps<{ open: boolean; visitId: string }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const rxQuery = useMedicalPrescription(computed(() => props.visitId), computed(() => props.open));
const rx = computed(() => rxQuery.data.value ?? null);

const print = () => window.print();
</script>
