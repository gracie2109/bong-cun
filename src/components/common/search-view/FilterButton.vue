<template>
  <SearchViewFilterPopover
    v-model:open="open"
    :active-count="activeCount"
    :width="width"
    @apply="emit('apply')"
    @reset="emit('reset')"
  >
    <slot />
  </SearchViewFilterPopover>
</template>

<script lang="ts" setup>
import { ref, watch } from "vue";
import SearchViewFilterPopover from "./SearchViewFilterPopover.vue";

/** The Filter button with its popover; the default slot holds the filter fields. */
withDefaults(defineProps<{ activeCount?: number; width?: string }>(), {
  activeCount: 0,
  width: "min(720px, 90vw)",
});
const emit = defineEmits<{ (event: "open"): void; (event: "apply"): void; (event: "reset"): void }>();
const open = ref(false);
watch(open, (isOpen) => {
  if (isOpen) emit("open");
});
</script>
