<template>
  <ImportDialog
    v-model:open="open"
    :title="$t('petCare.pets.import.title')"
    :importer="importer"
    :columns="PETS_PREVIEW_COLUMNS"
    can-download-errors
    @template="downloadPetsTemplate"
  >
    <template #notes>
      <p class="text-sm text-muted-foreground">{{ $t("petCare.pets.import.hint") }}</p>
    </template>
    <template #summary="{ report }">
      <p class="text-sm text-muted-foreground">
        {{ $t("petCare.pets.import.customers", { created: customerCount(report, "created_customers"), updated: customerCount(report, "updated_customers") }) }}
      </p>
    </template>
  </ImportDialog>
</template>

<script lang="ts" setup>
import ImportDialog from "@/components/common/data-io/ImportDialog.vue";
import type { ImportReport } from "@/lib/data-io/types";
import { downloadPetsTemplate } from "./downloadPetsTemplate";
import { PETS_PREVIEW_COLUMNS } from "./petsPreviewColumns";
import { usePetsImport } from "./usePetsImport";

const open = defineModel<boolean>("open", { required: true });
const importer = usePetsImport();

const customerCount = (report: ImportReport, key: string): number => Number(report.extra?.[key] ?? 0);
</script>
