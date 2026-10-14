<template>
  <DropdownMenu v-if="exporter.canExport.value">
    <DropdownMenuTrigger as-child>
      <Button variant="outline" size="sm" :disabled="exporter.disabled.value" :aria-label="$t('dataIo.download')">
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
import { Download, FileSpreadsheet, FileText, Loader2, Printer } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import type { ExportFormat } from "@/lib/data-io/columns";
import type { TableExporter } from "@/composables/useTableExport";

defineProps<{ exporter: TableExporter }>();

const ICONS: Record<ExportFormat, typeof Printer> = { pdf: Printer, xlsx: FileSpreadsheet, csv: FileText };
</script>
