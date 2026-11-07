<template>
  <div class="flex flex-wrap items-center gap-3 rounded-xl border bg-white p-3">
    <label class="flex min-h-11 items-center gap-2 text-sm">
      <input type="checkbox" class="size-5" :checked="allTicked" :disabled="!hasTickable" @change="emit('toggleAll')" />
      {{ $t("attendance.requests.selectAll") }}
    </label>
    <p class="text-sm font-semibold">{{ $t("attendance.requests.selected", { count }) }}</p>
    <Button type="button" class="ml-auto min-h-11" :disabled="!count" @click="emit('decide')">{{ $t("attendance.requests.decide") }}</Button>
  </div>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";

defineProps<{ count: number; allTicked: boolean; hasTickable: boolean }>();
const emit = defineEmits<{ toggleAll: []; decide: [] }>();
</script>
