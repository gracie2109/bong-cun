<template>
  <ImportDialog
    v-model:open="open"
    :title="$t('inventory.suppliers.import.title')"
    :importer="importer"
    :columns="PREVIEW_COLUMNS"
    can-download-errors
    @template="downloadSuppliersTemplate"
  >
    <template #notes>
      <p class="text-sm text-muted-foreground">{{ $t("inventory.suppliers.import.hint") }}</p>
    </template>
  </ImportDialog>
</template>

<script lang="ts" setup>
import ImportDialog from "@/components/common/data-io/ImportDialog.vue";
import type { PreviewColumn } from "@/composables/useTableImport";
import { downloadSuppliersTemplate } from "./downloadSuppliersTemplate";
import type { SupplierImportRow } from "@/types/dataImport";
import { useSuppliersImport } from "./useSuppliersImport";

const open = defineModel<boolean>("open", { required: true });
const importer = useSuppliersImport();

const PREVIEW_COLUMNS: PreviewColumn<SupplierImportRow>[] = [
  { label: "Tên", cell: (row) => row.name },
  { label: "Điện thoại", cell: (row) => row.phone },
  { label: "Mã số thuế", cell: (row) => row.tax_code },
];
</script>
