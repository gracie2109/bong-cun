<template>
  <Button v-if="auth.can('reports', 'EXPORT')" variant="outline" size="sm" :disabled="disabled || loading" @click="emit('export')">
    <Loader2 v-if="loading" class="mr-2 size-4 animate-spin" />
    <Download v-else class="mr-2 size-4" />
    {{ $t("reports.export.button") }}
  </Button>
</template>

<script lang="ts" setup>
import { Download, Loader2 } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { useAuthStore } from "@/stores";

defineProps<{ loading?: boolean; disabled?: boolean }>();
const emit = defineEmits<{ export: [] }>();

const auth = useAuthStore();
</script>
