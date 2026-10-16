<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <FileSpreadsheet class="size-4 text-primary" />
      {{ $t("productImport.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-5">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <ProductsNav />
        <ExportMenu :exporter="exporter" />
      </div>

      <p v-if="!canImportFiles" class="rounded-xl border bg-white p-4 text-sm text-muted-foreground">
        {{ $t("productImport.noPermission") }}
      </p>
      <template v-else>
        <TemplateDownload @download="downloadProductTemplate" />
        <ImportDropzone v-if="importer.phase.value === 'idle'" @file="importer.loadFile" />
        <p v-if="importer.readError.value" class="text-sm text-destructive">{{ $t("dataIo.import.readFailed") }}</p>

        <template v-if="importer.phase.value !== 'idle'">
          <div class="flex flex-wrap items-center justify-between gap-3">
            <p class="text-sm">
              <span class="font-semibold">{{ importer.fileName.value }}</span>
              <span class="ml-2 text-muted-foreground">{{ $t("dataIo.import.rowCount", { n: importer.rows.value.length }) }}</span>
            </p>
            <div class="flex items-center gap-2">
              <span v-if="importer.busy.value" class="flex items-center gap-2 text-sm text-muted-foreground">
                <Loader2 class="size-4 animate-spin" />
                {{ $t(importer.phase.value === "importing" ? "dataIo.import.importing" : "dataIo.import.checking", importer.progress.value) }}
              </span>
              <Button variant="outline" :disabled="importer.busy.value" @click="importer.reset()">
                {{ $t(importer.phase.value === "done" ? "dataIo.import.another" : "dataIo.import.cancel") }}
              </Button>
              <Button v-if="importer.phase.value !== 'done'" :disabled="!importer.canImport.value" @click="importer.confirmImport()">
                {{ $t("dataIo.import.importRows", { n: importer.rows.value.length }) }}
              </Button>
            </div>
          </div>

          <p v-if="importer.phase.value === 'done'" class="rounded-xl border border-primary/30 bg-primary/5 p-3 text-sm text-primary">
            {{ $t("dataIo.import.done") }}
          </p>
          <ul v-if="importer.fileNotes.value.length" class="space-y-1 rounded-xl border border-destructive/30 bg-destructive/5 p-3 text-sm text-destructive">
            <li v-for="note in importer.fileNotes.value" :key="note">{{ note }}</li>
          </ul>
          <ImportSummary v-if="importer.report.value" :report="importer.report.value" :error-count="importer.errorCount.value">
            <ProductImportExtras :report="importer.report.value" />
          </ImportSummary>
          <ImportPreviewTable :rows="importer.preview.value" :columns="PREVIEW_COLUMNS" can-download-errors @download-errors="importer.downloadErrors()" />
        </template>
      </template>
    </div>
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { FileSpreadsheet, Loader2 } from "lucide-vue-next";
import ExportMenu from "@/components/common/data-io/ExportMenu.vue";
import ImportDropzone from "@/components/common/data-io/ImportDropzone.vue";
import ImportPreviewTable from "@/components/common/data-io/ImportPreviewTable.vue";
import ImportSummary from "@/components/common/data-io/ImportSummary.vue";
import TemplateDownload from "@/components/common/data-io/TemplateDownload.vue";
import { Button } from "@/components/ui/button";
import { usePermission } from "@/composables/usePermission";
import { useAuthStore } from "@/stores";
import { ContentWrap, Header } from "@/features/admin/components";
import ProductsNav from "../ProductsNav.vue";
import { downloadProductTemplate } from "./downloadProductTemplate";
import { useProductsExport } from "./exportProducts";
import ProductImportExtras from "./ProductImportExtras.vue";
import { PREVIEW_COLUMNS } from "./previewColumns";
import { useProductImport } from "./useProductImport";

const auth = useAuthStore();
const { canCreate, canUpdate } = usePermission("products");
// Same rule as import_products: the IMPORT method, or CREATE and UPDATE together (older roles).
const canImportFiles = computed(() => auth.can("products", "IMPORT") || (canCreate.value && canUpdate.value));

const importer = useProductImport();
const exporter = useProductsExport();
</script>
