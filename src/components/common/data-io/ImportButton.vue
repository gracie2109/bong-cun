<template>
  <Button v-if="allowed" variant="outline" size="sm" @click="emit('click')">
    <Upload class="mr-2 size-4" />
    {{ $t("dataIo.import.button") }}
  </Button>
</template>

<script lang="ts" setup>
import { Upload } from "lucide-vue-next";
import { Button } from "@/components/ui/button";

defineProps<{ allowed: boolean }>();
const emit = defineEmits<{ click: [] }>();
</script>
