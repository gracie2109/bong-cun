<template>
  <div class="fixed inset-x-0 bottom-0 z-20 flex items-center justify-end gap-3 border-t bg-white px-6 py-3 shadow-lg">
    <span class="text-sm text-muted-foreground">{{ $t("petCare.prices.edited", { n: count }) }}</span>
    <Button variant="outline" :disabled="saving" @click="emit('discard')">
      {{ $t("petCare.prices.discard") }}
    </Button>
    <Button :disabled="saving" @click="emit('save')">{{ $t("petCare.prices.saveAll") }}</Button>
  </div>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";

defineProps<{ count: number; saving: boolean }>();

const emit = defineEmits<{ discard: []; save: [] }>();
</script>
