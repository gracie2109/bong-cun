<template>
  <div v-if="chips.length > 0" class="flex gap-1.5 overflow-x-auto pb-0.5">
    <button
      v-for="chip in allChips"
      :key="chip.id"
      type="button"
      class="shrink-0 rounded-full border px-3 py-1 text-xs font-semibold transition-colors"
      :class="modelValue === chip.id ? 'border-primary bg-primary text-primary-foreground' : 'text-muted-foreground hover:bg-muted'"
      :aria-pressed="modelValue === chip.id"
      @click="emit('update:modelValue', chip.id)"
    >
      {{ chip.name }}
    </button>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import type { CategoryChip } from "../useCategoryChips";

/** "All" plus one chip per category; "" is the "All" choice. */
const props = defineProps<{ chips: CategoryChip[]; modelValue: string }>();
const emit = defineEmits<{ "update:modelValue": [id: string] }>();

const { t } = useI18n();
const allChips = computed(() => [{ id: "", name: t("pos.catalog.allCategories"), count: 0 }, ...props.chips]);
</script>
