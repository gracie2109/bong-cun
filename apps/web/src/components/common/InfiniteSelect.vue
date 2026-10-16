<template>
  <Popover v-model:open="open">
    <PopoverTrigger as-child>
      <Button type="button" variant="outline" role="combobox" :disabled="disabled" class="w-full justify-between font-normal">
        <span class="truncate" :class="!selectedText && 'text-muted-foreground'">{{ selectedText || placeholder }}</span>
        <ChevronsUpDown class="ml-2 size-4 shrink-0 opacity-50" />
      </Button>
    </PopoverTrigger>
    <PopoverContent class="w-[--radix-popover-trigger-width] min-w-[14rem] p-0" align="start">
      <div class="border-b p-2">
        <Input v-model="search" :placeholder="searchPlaceholder ?? $t('common.search')" class="h-8" />
      </div>
      <ul class="max-h-64 overflow-y-auto py-1 text-sm">
        <li v-if="noneLabel">
          <button type="button" class="flex w-full items-center gap-2 px-3 py-2 text-left hover:bg-muted" @click="pick('')">
            <Check class="size-4" :class="modelValue === '' ? 'opacity-100' : 'opacity-0'" />
            {{ noneLabel }}
          </button>
        </li>
        <li v-for="option in options" :key="option.value">
          <button
            type="button"
            class="flex w-full items-center gap-2 px-3 py-2 text-left hover:bg-muted"
            @click="pick(option.value)"
          >
            <Check class="size-4 shrink-0" :class="modelValue === option.value ? 'opacity-100' : 'opacity-0'" />
            <span class="truncate">{{ option.label }}</span>
          </button>
        </li>
        <li v-if="options.length === 0 && !loading" class="px-3 py-2 text-muted-foreground">{{ emptyText ?? $t("pos.catalog.empty") }}</li>
        <li v-if="loading || loadingMore" class="px-3 py-2 text-muted-foreground">{{ $t("petCare.common.loading") }}</li>
        <li v-if="hasMore"><ScrollSentinel @visible="emit('loadMore')" /></li>
      </ul>
    </PopoverContent>
  </Popover>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { refDebounced } from "@vueuse/core";
import { Check, ChevronsUpDown } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { SEARCH_DEBOUNCE_MS } from "@/lib/listing";
import ScrollSentinel from "./ScrollSentinel.vue";

type Option = { value: string; label: string };

/**
 * A select whose options come from the server a page at a time: typing searches on the server
 * (debounced) and scrolling to the end of the list asks for the next page.
 */
const props = defineProps<{
  /** Selected value; "" is the "none" choice when `noneLabel` is given. */
  modelValue: string;
  options: Option[];
  placeholder: string;
  searchPlaceholder?: string;
  emptyText?: string;
  /** Adds a first choice that clears the selection. */
  noneLabel?: string;
  /** Label to show when the selected value is not among the loaded pages (an older saved choice). */
  selectedFallback?: string;
  hasMore?: boolean;
  loading?: boolean;
  loadingMore?: boolean;
  disabled?: boolean;
}>();

const emit = defineEmits<{ "update:modelValue": [value: string]; loadMore: []; "update:search": [text: string] }>();

const open = ref(false);
const search = ref("");
const debounced = refDebounced(search, SEARCH_DEBOUNCE_MS);
watch(debounced, (text) => emit("update:search", text));

const selectedText = computed(() => {
  if (props.modelValue === "") return props.noneLabel ?? "";
  return props.options.find((option) => option.value === props.modelValue)?.label ?? props.selectedFallback ?? "";
});

const pick = (value: string) => {
  emit("update:modelValue", value);
  open.value = false;
};
</script>
