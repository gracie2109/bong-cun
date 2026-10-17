<template>
  <div
    v-if="!isOnline"
    class="fixed inset-x-0 top-0 z-[10000] bg-red-600 px-4 py-2 text-center text-sm font-medium text-white"
    role="status"
  >
    {{ $t("native.offline") }}
  </div>
</template>

<script setup lang="ts">
import { useNetworkStatus } from "../composables/useNetworkStatus";

const { isOnline } = useNetworkStatus();
</script>
