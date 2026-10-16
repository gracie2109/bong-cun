<template>
  <section class="flex min-h-0 flex-col gap-2 rounded-xl border bg-muted/30 p-3">
    <h2 class="flex items-center justify-between text-sm font-semibold">
      {{ title }}
      <span class="rounded-full bg-white px-2 py-0.5 text-xs font-medium text-muted-foreground">{{ count }}</span>
    </h2>
    <div class="space-y-2 overflow-auto">
      <p v-if="count === 0" class="py-6 text-center text-xs text-muted-foreground">{{ $t("medical.queue.emptyColumn") }}</p>
      <slot />
    </div>
  </section>
</template>

<script lang="ts" setup>
defineProps<{ title: string; count: number }>();
</script>
