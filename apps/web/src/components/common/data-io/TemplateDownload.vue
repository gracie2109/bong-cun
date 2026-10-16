<template>
  <div class="flex flex-wrap items-center gap-2">
    <span class="text-sm text-muted-foreground">{{ $t("dataIo.import.template") }}</span>
    <Button variant="outline" size="sm" @click="emit('download', 'xlsx')">
      <FileSpreadsheet class="mr-2 size-4" />
      Excel
    </Button>
    <Button variant="outline" size="sm" @click="emit('download', 'csv')">
      <FileText class="mr-2 size-4" />
      CSV
    </Button>
  </div>
</template>

<script lang="ts" setup>
import { FileSpreadsheet, FileText } from "lucide-vue-next";
import { Button } from "@/components/ui/button";

const emit = defineEmits<{ download: [format: "xlsx" | "csv"] }>();
</script>
