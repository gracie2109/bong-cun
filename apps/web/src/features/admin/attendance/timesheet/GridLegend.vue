<template>
  <ul class="flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted-foreground">
    <li v-for="code in GRID_CODES" :key="code" class="flex items-center gap-1.5">
      <span class="inline-flex size-6 items-center justify-center rounded font-semibold" :class="CODE_TONE[code]">{{ code }}</span>
      {{ $t(`attendance.timesheet.codes.${code}`) }}
    </li>
  </ul>
</template>

<script lang="ts" setup>
import { CODE_TONE, GRID_CODES } from "./gridCodes";
</script>
