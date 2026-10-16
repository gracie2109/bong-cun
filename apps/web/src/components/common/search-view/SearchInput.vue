<template>
  <div class="relative min-w-60 flex-1">
    <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
    <Input v-model="text" class="px-9" :placeholder="placeholder" @keydown.enter.prevent="emit('submit')" />
    <button
      v-if="text"
      type="button"
      class="absolute right-2 top-1/2 -translate-y-1/2 rounded p-1 text-muted-foreground hover:bg-muted"
      :aria-label="$t('common.searchView.clearText')"
      @click="text = ''"
    >
      <X class="size-3.5" />
    </button>
  </div>
</template>

<script lang="ts" setup>
import { Search, X } from "lucide-vue-next";
import { Input } from "@/components/ui/input";

defineProps<{ placeholder?: string }>();
const emit = defineEmits<{ (event: "submit"): void }>();
const text = defineModel<string>({ default: "" });
</script>
