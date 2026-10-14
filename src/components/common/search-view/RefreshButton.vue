<template>
  <ToolbarIconButton :icon="RefreshCw" :label="$t('common.searchView.refresh')" :loading="refreshing" />
</template>

<script lang="ts" setup>
import { RefreshCw } from "lucide-vue-next";
import ToolbarIconButton from "./ToolbarIconButton.vue";

/** Reloads the list; the icon spins while it loads. */
defineProps<{ refreshing?: boolean }>();
</script>
