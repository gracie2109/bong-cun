<template>
  <div class="inline-flex h-12 items-center rounded-full border bg-white" role="group" :aria-label="$t('shop.quantity')">
    <button
      type="button"
      class="grid size-12 place-content-center rounded-full transition-colors hover:bg-muted disabled:opacity-40"
      :aria-label="$t('shop.less')"
      :disabled="modelValue <= min"
      @click="set(modelValue - 1)"
    >
      <Minus class="size-4" />
    </button>
    <span class="w-10 text-center font-semibold tabular-nums" aria-live="polite">{{ modelValue }}</span>
    <button
      type="button"
      class="grid size-12 place-content-center rounded-full transition-colors hover:bg-muted disabled:opacity-40"
      :aria-label="$t('shop.more')"
      :disabled="modelValue >= max"
      @click="set(modelValue + 1)"
    >
      <Plus class="size-4" />
    </button>
  </div>
</template>

<script lang="ts" setup>
import { Minus, Plus } from "lucide-vue-next";

const props = withDefaults(defineProps<{ modelValue: number; min?: number; max?: number }>(), { min: 1, max: 99 });
const emit = defineEmits<{ "update:modelValue": [value: number] }>();

const set = (value: number) => emit("update:modelValue", Math.min(props.max, Math.max(props.min, value)));
</script>
