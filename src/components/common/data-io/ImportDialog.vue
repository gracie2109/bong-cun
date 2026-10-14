<template>
  <AppDialog
    v-model:open="open"
    :title="title"
    :ok-text="$t('dataIo.import.importRows', { n: importer.rows.value.length })"
    :ok-disabled="!importer.canImport.value"
    :busy="importer.phase.value === 'importing'"
    :hide-cancel="false"
    persistent
    content-class="sm:max-w-5xl"
    @ok="importer.confirmImport()"
    @cancel="importer.reset()"
  >
    <div class="flex flex-col gap-4">
      <TemplateDownload @download="(format) => emit('template', format)" />
      <slot name="notes" />
      <ImportDropzone v-if="importer.phase.value === 'idle'" @file="importer.loadFile" />
      <p v-if="importer.readError.value" class="text-sm text-destructive">{{ $t("dataIo.import.readFailed") }}</p>

      <template v-if="importer.phase.value !== 'idle'">
        <p class="text-sm">
          <span class="font-semibold">{{ importer.fileName.value }}</span>
          <span class="ml-2 text-muted-foreground">{{ $t("dataIo.import.rowCount", { n: importer.rows.value.length }) }}</span>
          <span v-if="importer.busy.value" class="ml-3 inline-flex items-center gap-2 text-muted-foreground">
            <Loader2 class="size-4 animate-spin" />
            {{ $t(importer.phase.value === "importing" ? "dataIo.import.importing" : "dataIo.import.checking", importer.progress.value) }}
          </span>
        </p>
        <p v-if="importer.phase.value === 'done'" class="rounded-xl border border-primary/30 bg-primary/5 p-3 text-sm text-primary">
          {{ $t("dataIo.import.done") }}
        </p>
        <ul v-if="importer.fileNotes.value.length" class="space-y-1 rounded-xl border border-destructive/30 bg-destructive/5 p-3 text-sm text-destructive">
          <li v-for="note in importer.fileNotes.value" :key="note">{{ note }}</li>
        </ul>
        <ImportSummary v-if="importer.report.value" :report="importer.report.value" :error-count="importer.errorCount.value">
          <slot name="summary" :report="importer.report.value" />
        </ImportSummary>
        <div class="flex h-80 min-h-0 flex-col">
          <ImportPreviewTable
            :rows="importer.preview.value"
            :columns="columns"
            :can-download-errors="canDownloadErrors"
            @download-errors="importer.downloadErrors()"
          />
        </div>
        <Button v-if="!importer.busy.value" variant="outline" size="sm" class="self-start" @click="importer.reset()">
          {{ $t(importer.phase.value === "done" ? "dataIo.import.another" : "dataIo.import.cancel") }}
        </Button>
      </template>
    </div>
  </AppDialog>
</template>

<script lang="ts" setup generic="R">
import { Loader2 } from "lucide-vue-next";
import AppDialog from "@/components/common/AppDialog.vue";
import { Button } from "@/components/ui/button";
import type { PreviewColumn, TableImport } from "@/composables/useTableImport";
import ImportDropzone from "./ImportDropzone.vue";
import ImportPreviewTable from "./ImportPreviewTable.vue";
import ImportSummary from "./ImportSummary.vue";
import TemplateDownload from "./TemplateDownload.vue";

defineProps<{ title: string; importer: TableImport<R>; columns: PreviewColumn<R>[]; canDownloadErrors?: boolean }>();
const emit = defineEmits<{ template: [format: "xlsx" | "csv"] }>();
const open = defineModel<boolean>("open", { required: true });
</script>
