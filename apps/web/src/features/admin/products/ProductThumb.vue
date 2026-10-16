<template>
  <div class="flex items-center justify-center overflow-hidden rounded-md border bg-muted/40">
    <img v-if="src && !failed" :src="src" alt="" class="size-full object-cover" @error="failed = true" />
    <ImageIcon v-else class="size-1/2 max-h-8 max-w-8 text-muted-foreground" />
  </div>
</template>

<script lang="ts" setup>
import { ref, watch } from "vue";
import { Image as ImageIcon } from "lucide-vue-next";

const props = defineProps<{ src?: string | null }>();
const failed = ref(false);

watch(
  () => props.src,
  () => {
    failed.value = false;
  }
);
</script>
