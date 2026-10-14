<template>
  <ToolbarIconButton v-if="allowed && compact" :icon="Upload" :label="$t('dataIo.import.button')" @click="emit('click')" />
  <Button v-else-if="allowed" variant="outline" size="sm" @click="emit('click')">
    <Upload class="mr-2 size-4" />
    {{ $t("dataIo.import.button") }}
  </Button>
</template>

<script lang="ts" setup>
import { Upload } from "lucide-vue-next";
import ToolbarIconButton from "@/components/common/search-view/ToolbarIconButton.vue";
import { Button } from "@/components/ui/button";

defineProps<{ allowed: boolean; /** Only the icon, for a SearchView toolbar. */ compact?: boolean }>();
const emit = defineEmits<{ click: [] }>();
</script>
