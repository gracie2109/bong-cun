<template>
  <div class="relative h-full" :class="editing && 'rounded-xl outline-dashed outline-2 outline-offset-2 outline-primary/50'">
    <component
      :is="type.component"
      v-if="type"
      v-bind="type.byMetric ? { config: item.config } : {}"
      class="h-full"
      :class="editing && 'pointer-events-none select-none'"
    />
    <section v-else class="flex h-full flex-col justify-center gap-2 rounded-xl border border-dashed bg-white p-4 text-sm text-muted-foreground">
      {{ $t("dashboard.layout.unknownWidget") }}
    </section>

    <template v-if="editing">
      <!-- 44px touch targets: the handle drags, the menu is the no-drag way to move and resize. -->
      <button
        type="button"
        class="dashboard-drag-handle absolute left-1 top-1 z-10 flex size-11 cursor-grab touch-none items-center justify-center rounded-lg bg-primary text-primary-foreground shadow active:cursor-grabbing"
        :aria-label="$t('dashboard.layout.dragHandle')"
      >
        <GripVertical class="size-5" />
      </button>
      <div class="absolute right-1 top-1 z-10">
        <ItemEditMenu
          @move="(step) => emit('move', step)"
          @resize="(preset) => emit('resize', preset)"
          @remove="emit('remove')"
        />
      </div>
    </template>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { GripVertical } from "lucide-vue-next";
import type { SavedItem } from "@bongcun/core/dashboard";
import { widgetType } from "../widgetTypes/registry";
import ItemEditMenu from "./ItemEditMenu.vue";
import type { SizePreset } from "./useItemActions";

const props = defineProps<{ item: SavedItem; editing?: boolean }>();
const emit = defineEmits<{ move: [step: -1 | 1]; resize: [preset: SizePreset]; remove: [] }>();

const type = computed(() => widgetType(props.item.type));
</script>
