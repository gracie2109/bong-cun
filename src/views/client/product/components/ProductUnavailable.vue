<template>
  <div class="grid place-items-center gap-4 rounded-xl border bg-white py-20 text-center">
    <img :src="emptyBox" alt="" class="w-28 opacity-80" />
    <p class="text-lg font-semibold">{{ $t(failed ? "client.catalog.error" : "client.product.discontinued") }}</p>
    <Button v-if="failed" variant="outline" @click="emit('retry')">{{ $t("client.catalog.retry") }}</Button>
    <Button v-else as-child><RouterLink :to="{ name: 'products' }">{{ $t("client.nav.products") }}</RouterLink></Button>
  </div>
</template>

<script lang="ts" setup>
import emptyBox from "@/assets/empty-box.png";
import { Button } from "@/components/ui/button";

defineProps<{ failed: boolean }>();
const emit = defineEmits<{ retry: [] }>();
</script>
