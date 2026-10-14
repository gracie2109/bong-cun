<template>
  <ToolbarIconButton :icon="FilterX" :label="$t('common.searchView.clear')" :disabled="disabled" />
</template>

<script lang="ts" setup>
import { FilterX } from "lucide-vue-next";
import ToolbarIconButton from "./ToolbarIconButton.vue";

/** Clears the search and filters; clicks come through as the native click. */
defineProps<{ disabled?: boolean }>();
</script>
