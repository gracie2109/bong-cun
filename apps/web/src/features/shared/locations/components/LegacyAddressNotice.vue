<template>
  <div class="rounded-lg border border-amber-300 bg-amber-50 px-3 py-2 text-sm text-amber-900">
    <p class="font-medium">{{ $t("shop.location.legacyTitle") }}</p>
    <p class="mt-0.5 text-xs">
      {{ $t("shop.location.legacyOld", { place: oldPlace }) }}
    </p>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";

const props = defineProps<{ wardName: string; districtName: string; provinceName: string }>();

const oldPlace = computed(() => [props.wardName, props.districtName, props.provinceName].filter(Boolean).join(", "));
</script>
