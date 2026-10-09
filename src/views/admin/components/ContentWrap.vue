<template>
  <div
    class="mx-auto w-full max-w-[1600px] px-4 py-6 md:px-6"
    :class="{
      'flex h-[calc(100dvh-3.5rem)] min-h-[34rem] flex-col': fill === true,
      'xl:flex xl:h-[calc(100dvh-3.5rem)] xl:min-h-[34rem] xl:flex-col': fill === 'xl',
    }"
  >
    <slot />
  </div>
</template>

<script lang="ts" setup>
/**
 * `fill` makes the page exactly as tall as the screen below the header, as a column, so a list
 * can take all the height that is left and scroll inside its own frame instead of the page.
 * `"xl"` does it only on wide screens, where a layout with two columns fits side by side.
 */
defineProps<{ fill?: boolean | "xl" }>();
</script>
