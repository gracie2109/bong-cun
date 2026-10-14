<template>
  <Popover v-model:open="open">
    <PopoverTrigger as-child>
      <ToolbarIconButton :label="$t('common.searchView.filter')" :badge="activeCount">
        <ListFilter class="size-4" />
      </ToolbarIconButton>
    </PopoverTrigger>
    <PopoverContent align="end" class="p-0" :style="{ width }" @keydown.enter="onEnter">
      <div class="flex items-center justify-between border-b px-4 py-3">
        <span class="text-sm font-semibold">{{ $t("common.searchView.filter") }}</span>
        <button type="button" class="rounded p-1 text-muted-foreground hover:bg-muted" :aria-label="$t('common.cancel')" @click="open = false">
          <X class="size-4" />
        </button>
      </div>
      <div class="grid max-h-[60vh] grid-cols-1 gap-4 overflow-y-auto p-4 sm:grid-cols-2 lg:grid-cols-3">
        <slot />
      </div>
      <div class="flex justify-end gap-2 border-t px-4 py-3">
        <Button type="button" variant="outline" @click="emit('reset')">{{ $t("common.searchView.reset") }}</Button>
        <Button type="button" @click="apply">{{ $t("common.searchView.apply") }}</Button>
      </div>
    </PopoverContent>
  </Popover>
</template>

<script lang="ts" setup>
import { ListFilter, X } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import ToolbarIconButton from "./ToolbarIconButton.vue";

defineProps<{ activeCount: number; width: string }>();
const emit = defineEmits<{ (event: "apply"): void; (event: "reset"): void }>();
const open = defineModel<boolean>("open", { default: false });

const apply = () => {
  emit("apply");
  open.value = false;
};

// Enter applies, except where it belongs to the control (a textarea, a button, an open list).
const onEnter = (event: KeyboardEvent) => {
  const target = event.target as HTMLElement | null;
  if (target?.closest("textarea, button, [role='option'], [role='combobox']")) return;
  event.preventDefault();
  apply();
};
</script>
