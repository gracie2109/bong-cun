<template>
  <div :class="['mx-0 my-12 relative', className]">
    <slot></slot>
  </div>
</template>

<script lang="ts" setup>
interface Props {
  className?: string;
}

defineProps<Props>();
</script>
