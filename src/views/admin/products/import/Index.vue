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
        <div class="flex flex-wrap gap-2">
          <Button variant="outline" @click="downloadTemplate">
            <Download class="mr-2 size-4" />
            {{ $t("productImport.template") }}
          </Button>
          <Button variant="outline" :disabled="exporting" @click="exportAll">
            <Loader2 v-if="exporting" class="mr-2 size-4 animate-spin" />
            <FileDown v-else class="mr-2 size-4" />
            {{ $t("productImport.exportAll") }}
          </Button>
        </div>
      </div>

      <p v-if="!canImportFiles" class="rounded-xl border bg-white p-4 text-sm text-muted-foreground">
        {{ $t("productImport.noPermission") }}
      </p>
      <template v-else>
        <ImportDropzone v-if="phase === 'idle'" @file="loadFile" />
        <p v-if="readError" class="text-sm text-destructive">{{ $t("productImport.readFailed") }}</p>

        <template v-if="phase !== 'idle'">
          <div class="flex flex-wrap items-center justify-between gap-3">
            <p class="text-sm">
              <span class="font-semibold">{{ fileName }}</span>
              <span class="ml-2 text-muted-foreground">{{ $t("productImport.rowCount", { n: rows.length }) }}</span>
            </p>
            <div class="flex items-center gap-2">
              <span v-if="busy" class="flex items-center gap-2 text-sm text-muted-foreground">
                <Loader2 class="size-4 animate-spin" />
                {{ $t(phase === "importing" ? "productImport.importing" : "productImport.checking", progress) }}
              </span>
              <Button variant="outline" :disabled="busy" @click="reset">{{ $t(phase === "done" ? "productImport.another" : "productImport.cancel") }}</Button>
              <Button v-if="phase !== 'done'" :disabled="!canImport" @click="confirmImport">
                {{ $t("productImport.import") }}
              </Button>
            </div>
          </div>

          <p v-if="phase === 'done'" class="rounded-xl border border-primary/30 bg-primary/5 p-3 text-sm text-primary">
            {{ $t("productImport.done") }}
          </p>
          <ul v-if="fileNotes.length" class="space-y-1 rounded-xl border border-destructive/30 bg-destructive/5 p-3 text-sm text-destructive">
            <li v-for="note in fileNotes" :key="note">{{ note }}</li>
          </ul>
          <ImportSummary v-if="report" :report="report" :error-count="errorCount" />
          <ImportPreviewTable :rows="preview" />
        </template>
      </template>
    </div>
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Download, FileDown, FileSpreadsheet, Loader2 } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { usePermission } from "@/composables/usePermission";
import { ContentWrap, Header } from "@/views/admin/components";
import ProductsNav from "../ProductsNav.vue";
import ImportDropzone from "./ImportDropzone.vue";
import ImportPreviewTable from "./ImportPreviewTable.vue";
import ImportSummary from "./ImportSummary.vue";
import { downloadExport, downloadTemplate, useExportAll } from "./exportProducts";
import { useProductImport } from "./useProductImport";

const { canCreate, canUpdate } = usePermission("products");
// The database needs both grants for an import; the export only needs to see products.
const canImportFiles = computed(() => canCreate.value && canUpdate.value);

const { phase, fileName, report, progress, readError, rows, fileNotes, preview, errorCount, canImport, loadFile, confirmImport, reset } =
  useProductImport();
const busy = computed(() => phase.value === "reading" || phase.value === "checking" || phase.value === "importing");

const { exporting, exportAll } = useExportAll(downloadExport);
</script>
