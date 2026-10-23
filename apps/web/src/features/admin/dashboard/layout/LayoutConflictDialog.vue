<template>
  <AppDialog
    :open="open"
    :title="$t('dashboard.layout.conflictTitle')"
    :description="$t('dashboard.layout.conflictDesc')"
    :ok-text="$t('dashboard.layout.overwrite')"
    :cancel-text="$t('dashboard.layout.reload')"
    size="sm"
    @ok="emit('overwrite')"
    @cancel="emit('reload')"
  />
</template>

<script lang="ts" setup>
import AppDialog from "@/components/common/AppDialog.vue";

defineProps<{ open: boolean }>();
const emit = defineEmits<{ overwrite: []; reload: [] }>();
</script>
