<template>
  <Button type="button" variant="outline" size="sm" @click="open = true">
    <Upload class="mr-2 size-4" />
    {{ $t("inventory.documents.fill.button") }}
  </Button>
  <ImportDialog
    v-model:open="open"
    :title="$t('inventory.documents.fill.title')"
    :ok-text="$t('inventory.documents.fill.ok', { n: validCount })"
    :importer="importer"
    :columns="PREVIEW_COLUMNS"
    can-download-errors
    @template="downloadReceiptTemplate"
  >
    <template #notes>
      <p class="text-sm text-muted-foreground">{{ $t("inventory.documents.fill.hint") }}</p>
    </template>
  </ImportDialog>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { Upload } from "lucide-vue-next";
import ImportDialog from "@/components/common/data-io/ImportDialog.vue";
import { Button } from "@/components/ui/button";
import type { PreviewColumn } from "@/composables/useTableImport";
import type { EditLine } from "../documentLines";
import { downloadReceiptTemplate } from "./downloadReceiptTemplate";
import type { ReceiptFileRow } from "./receiptFileRow";
import { useReceiptFileFill } from "./useReceiptFileFill";

const emit = defineEmits<{ lines: [lines: EditLine[]] }>();

const open = ref(false);
const importer = useReceiptFileFill((lines) => emit("lines", lines));
// The lines are in the receipt once the file is "imported": close and clear the dialog.
watch(
  () => importer.phase.value,
  (phase) => {
    if (phase !== "done") return;
    open.value = false;
    importer.reset();
  }
);
const validCount = computed(() => importer.rows.value.length - importer.errorCount.value);

const PREVIEW_COLUMNS: PreviewColumn<ReceiptFileRow>[] = [
  { label: "SKU", cell: (row) => row.sku },
  { label: "Số lượng", cell: (row) => row.qty ?? "", right: true },
  { label: "Đơn vị", cell: (row) => row.unit },
  { label: "Giá nhập", cell: (row) => row.cost ?? "", right: true },
  { label: "Số lô", cell: (row) => row.lotNo },
  { label: "Hạn dùng", cell: (row) => row.expiry ?? "" },
];
</script>
