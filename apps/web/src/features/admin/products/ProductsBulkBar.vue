<template>
  <div class="flex flex-wrap items-center gap-3 rounded-xl border border-primary/30 bg-primary/5 px-4 py-2 text-sm">
    <span class="font-semibold">{{ $t("products.delete.selected", { n: count }) }}</span>
    <Button variant="ghost" size="sm" @click="emit('clear')">{{ $t("products.delete.clear") }}</Button>
    <Button variant="destructive" size="sm" class="ml-auto" @click="emit('delete')">
      <Trash2 class="mr-2 size-4" />
      {{ $t("products.delete.action") }}
    </Button>
  </div>
</template>

<script lang="ts" setup>
import { Trash2 } from "lucide-vue-next";
import { Button } from "@/components/ui/button";

defineProps<{ count: number }>();
const emit = defineEmits<{ clear: []; delete: [] }>();
</script>
