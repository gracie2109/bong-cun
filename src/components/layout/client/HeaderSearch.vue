<template>
  <form role="search" class="group relative w-full" @submit.prevent="submit(); emit('submitted')">
    <label :for="inputId" class="sr-only">{{ $t("client.header.searchLabel") }}</label>
    <Search class="pointer-events-none absolute left-4 top-1/2 size-[18px] -translate-y-1/2 text-muted-foreground transition-colors group-focus-within:text-primary" />
    <input
      :id="inputId"
      v-model="text"
      type="search"
      enterkeyhint="search"
      autocomplete="off"
      :placeholder="$t('client.header.searchPlaceholder')"
      class="h-11 w-full rounded-full border border-transparent bg-muted pl-11 pr-4 text-sm text-foreground outline-none transition-[background-color,border-color,box-shadow] duration-200 placeholder:text-muted-foreground hover:bg-secondary focus:border-primary/40 focus:bg-white focus:shadow-[0_0_0_4px_hsl(var(--primary)/0.12)]"
    />
  </form>
</template>

<script setup lang="ts">
import { useId } from "vue";
import { Search } from "lucide-vue-next";
import { useHeaderSearch } from "@/composables/layout/useHeaderSearch";

const emit = defineEmits<{ submitted: [] }>();
const inputId = useId();
const { text, submit } = useHeaderSearch();
</script>
