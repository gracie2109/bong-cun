<template>
  <div class="inline-flex rounded-full bg-muted p-0.5 text-xs font-semibold" role="group" :aria-label="$t('client.header.language')">
    <button
      v-for="code in LOCALES"
      :key="code"
      type="button"
      class="h-7 min-w-9 rounded-full px-2 uppercase transition-colors"
      :class="locale === code ? 'bg-white text-foreground shadow-sm' : 'text-muted-foreground hover:text-foreground'"
      :aria-pressed="locale === code"
      @click="setLocale(code)"
    >
      {{ code }}
    </button>
  </div>
</template>

<script setup lang="ts">
import { useI18n } from "vue-i18n";

const LOCALES = ["vi", "en"] as const;
const { locale, setLocale } = useI18n();
</script>
