<template>
  <component :is="type.component" v-if="type" class="h-full" />
  <section v-else class="flex h-full flex-col justify-center gap-2 rounded-xl border border-dashed bg-white p-4 text-sm text-muted-foreground">
    {{ $t("dashboard.layout.unknownWidget") }}
  </section>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import type { SavedItem } from "@bongcun/core/dashboard";
import { widgetType } from "../widgetTypes/registry";

const props = defineProps<{ item: SavedItem }>();
const type = computed(() => widgetType(props.item.type));
</script>
