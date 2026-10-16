<template>
  <span class="rounded-full bg-violet-100 px-1.5 py-0.5 text-[10px] font-semibold text-violet-800">
    {{ $t(`boarding.board.purpose.${purpose}`) }}
  </span>
</template>

<script lang="ts" setup>
defineProps<{ purpose: "medical" | "isolation" }>();
</script>
