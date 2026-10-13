<template>
  <label
    class="flex cursor-pointer flex-col items-center justify-center gap-2 rounded-xl border-2 border-dashed bg-white px-6 py-12 text-center transition-colors"
    :class="dragging ? 'border-primary bg-primary/5' : 'border-muted-foreground/30 hover:border-primary/60'"
    @dragover.prevent="dragging = true"
    @dragleave.prevent="dragging = false"
    @drop.prevent="onDrop"
  >
    <FileSpreadsheet class="size-10 text-primary/70" />
    <span class="font-semibold">{{ $t("productImport.dropTitle") }}</span>
    <span class="text-sm text-muted-foreground">{{ $t("productImport.dropHint") }}</span>
    <input type="file" class="sr-only" accept=".xlsx" :disabled="disabled" @change="onPick" />
  </label>
</template>

<script lang="ts" setup>
import { ref } from "vue";
import { FileSpreadsheet } from "lucide-vue-next";

defineProps<{ disabled?: boolean }>();
const emit = defineEmits<{ file: [file: File] }>();

const dragging = ref(false);

const onPick = (event: Event) => {
  const input = event.target as HTMLInputElement;
  const file = input.files?.[0];
  if (file) emit("file", file);
  input.value = "";
};

const onDrop = (event: DragEvent) => {
  dragging.value = false;
  const file = event.dataTransfer?.files?.[0];
  if (file) emit("file", file);
};
</script>
