<template>
  <Popover v-model:open="open">
    <PopoverTrigger as-child>
      <Button type="button" variant="outline" role="combobox" :aria-expanded="open" :disabled="disabled" class="w-full justify-between font-normal">
        <span v-if="selectedLabel" class="truncate">{{ selectedLabel }}</span>
        <span v-else class="truncate text-muted-foreground">{{ placeholder }}</span>
        <ChevronsUpDown class="ml-2 size-4 shrink-0 opacity-50" />
      </Button>
    </PopoverTrigger>
    <PopoverContent class="z-[1000] w-[--reka-popover-trigger-width] min-w-[260px] bg-white p-0">
      <Command ignore-filter :model-value="modelValue ?? undefined" @update:model-value="onPick">
        <CommandInput v-model="query" :placeholder="searchPlaceholder" />
        <p v-if="loading" class="px-3 py-6 text-center text-sm text-muted-foreground">{{ $t("shop.location.loading") }}</p>
        <div v-else-if="failed" class="space-y-2 px-3 py-6 text-center text-sm">
          <p class="text-red-600">{{ $t("shop.location.failed") }}</p>
          <Button type="button" size="sm" variant="outline" @click="$emit('retry')">{{ $t("shop.location.retry") }}</Button>
        </div>
        <template v-else>
          <p v-if="visible.length === 0" class="px-3 py-6 text-center text-sm text-muted-foreground">{{ emptyText }}</p>
          <CommandList>
            <CommandGroup>
              <CommandItem v-for="option in visible" :key="option.value" :value="option.value" class="cursor-pointer">
                <Check class="mr-2 size-4 shrink-0" :class="option.value === modelValue ? 'opacity-100' : 'opacity-0'" />
                <span>{{ option.label }}</span>
                <span v-if="option.hint" class="ml-2 text-xs text-muted-foreground">({{ option.hint }})</span>
              </CommandItem>
            </CommandGroup>
          </CommandList>
        </template>
      </Command>
    </PopoverContent>
  </Popover>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { Check, ChevronsUpDown } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Command, CommandGroup, CommandInput, CommandItem, CommandList } from "@/components/ui/command";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { filterOptions } from "../helpers/pickerState";
import type { PickerOption } from "../types";

const props = defineProps<{
  options: PickerOption[];
  modelValue: string | null;
  /** Shown while the list is still empty, e.g. a saved choice whose list has not loaded yet. */
  fallbackLabel?: string;
  placeholder: string;
  searchPlaceholder: string;
  emptyText: string;
  disabled?: boolean;
  loading?: boolean;
  failed?: boolean;
}>();
const emit = defineEmits<{ "update:modelValue": [value: string]; retry: [] }>();

const open = ref(false);
const query = ref("");
watch(open, (isOpen) => {
  if (isOpen) query.value = "";
});

const visible = computed(() => filterOptions(props.options, query.value));
const selectedLabel = computed(() => props.options.find((option) => option.value === props.modelValue)?.label ?? props.fallbackLabel ?? "");

const onPick = (value: unknown) => {
  if (typeof value !== "string") return;
  emit("update:modelValue", value);
  open.value = false;
};
</script>
