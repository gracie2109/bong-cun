<template>
  <div class="flex flex-wrap items-center gap-x-5 gap-y-2 border-t px-4 py-3 text-xs text-muted-foreground">
    <span class="flex items-center gap-1.5">
      <Checkbox :checked="true" disabled class="size-4 border-muted-foreground/40 data-[state=checked]:bg-muted-foreground/40" />
      {{ $t("rbac.matrix.legendSystem") }}
    </span>
    <span class="flex items-center gap-1.5">
      <Checkbox :checked="true" class="pointer-events-none size-4" tabindex="-1" />
      {{ $t("rbac.matrix.legendFull") }}
    </span>
    <span class="flex items-center gap-1.5">
      <Checkbox checked="indeterminate" class="pointer-events-none size-4" tabindex="-1" />
      {{ $t("rbac.matrix.legendPartial") }}
    </span>
    <span class="flex items-center gap-1.5">
      <Checkbox :checked="false" class="pointer-events-none size-4" tabindex="-1" />
      {{ $t("rbac.matrix.legendNone") }}
    </span>
    <span class="ml-auto">{{ $t("rbac.matrix.showing", { n: shown, total }) }}</span>
  </div>
</template>

<script lang="ts" setup>
import { Checkbox } from "@/components/ui/checkbox";

defineProps<{ shown: number; total: number }>();
</script>
