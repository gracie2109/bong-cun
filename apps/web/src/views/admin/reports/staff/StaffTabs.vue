<template>
  <div class="flex gap-1 rounded-lg border bg-white p-0.5">
    <button
      v-for="item in ROLES"
      :key="item"
      type="button"
      class="rounded-md px-3 py-1.5 text-sm font-semibold transition-colors"
      :class="role === item ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:bg-muted'"
      @click="role = item"
    >
      {{ $t(`reports.staff.roles.${item}`) }}
    </button>
  </div>
</template>

<script lang="ts" setup>
import type { StaffRole } from "@bongcun/supabase/reports";

const role = defineModel<StaffRole>("role", { required: true });
const ROLES: StaffRole[] = ["cashier", "spa"];
</script>
