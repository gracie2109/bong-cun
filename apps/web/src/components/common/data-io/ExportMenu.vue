<template>
  <DropdownMenu v-if="exporter.canExport.value">
    <DropdownMenuTrigger as-child>
      <ToolbarIconButton
        v-if="compact"
        :icon="exporter.exporting.value ? Loader2 : Download"
        :loading="exporter.exporting.value"
        :label="progressLabel ?? $t('dataIo.download')"
        :disabled="exporter.disabled.value"
      />
      <Button v-else variant="outline" size="sm" :disabled="exporter.disabled.value" :aria-label="$t('dataIo.download')">
        <Loader2 v-if="exporter.exporting.value" class="mr-2 size-4 animate-spin" />
        <Download v-else class="mr-2 size-4" />
        <span v-if="exporter.progress.value">
          {{ $t("dataIo.progress", { done: exporter.progress.value.done.toLocaleString("vi-VN"), total: exporter.progress.value.total.toLocaleString("vi-VN") }) }}
        </span>
        <span v-else>{{ $t("dataIo.download") }}</span>
      </Button>
    </DropdownMenuTrigger>
    <DropdownMenuContent align="end">
      <DropdownMenuItem v-for="format in exporter.formats" :key="format" @click="exporter.run(format)">
        <component :is="ICONS[format]" class="mr-2 size-4 text-muted-foreground" />
        {{ $t(`dataIo.format.${format}`) }}
      </DropdownMenuItem>
    </DropdownMenuContent>
  </DropdownMenu>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import ToolbarIconButton from "@/components/common/search-view/ToolbarIconButton.vue";
import { Download, FileSpreadsheet, FileText, Loader2, Printer } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import type { ExportFormat } from "@/lib/data-io/columns";
import type { TableExporter } from "@/composables/useTableExport";

const props = defineProps<{
  exporter: TableExporter;
  /** Only the download icon (for a SearchView toolbar); the label becomes its tooltip. */
  compact?: boolean;
}>();

const { t } = useI18n();
const progressLabel = computed(() => {
  const progress = props.exporter.progress.value;
  if (!progress) return undefined;
  return t("dataIo.progress", { done: progress.done.toLocaleString("vi-VN"), total: progress.total.toLocaleString("vi-VN") });
});

const ICONS: Record<ExportFormat, typeof Printer> = { pdf: Printer, xlsx: FileSpreadsheet, csv: FileText };
</script>
