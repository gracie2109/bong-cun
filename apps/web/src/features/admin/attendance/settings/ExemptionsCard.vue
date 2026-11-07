<template>
  <section class="rounded-xl border bg-white">
    <header class="border-b px-4 py-3">
      <h2 class="font-semibold">{{ $t("attendance.publish.exemptions.title") }}</h2>
      <p class="text-xs text-muted-foreground">{{ $t("attendance.publish.exemptions.hint") }}</p>
    </header>
    <ul v-if="rows.length" class="divide-y">
      <li v-for="row in rows" :key="row.userId" class="flex items-center justify-between gap-3 px-4 py-2">
        <span class="text-sm">
          {{ row.name }}
          <span v-if="row.state === 'manager'" class="ml-1 text-xs text-muted-foreground">{{ $t("attendance.publish.exemptions.manager") }}</span>
        </span>
        <Switch
          :checked="row.state === 'exempt'"
          :disabled="!canEdit || row.state === 'manager' || mutation.isPending.value"
          :aria-label="$t('attendance.publish.exemptions.toggle', { name: row.name })"
          @update:checked="toggle(row.userId, $event)"
        />
      </li>
    </ul>
    <p v-else class="px-4 py-6 text-center text-sm text-muted-foreground">{{ $t("attendance.publish.exemptions.empty") }}</p>
  </section>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Switch } from "@/components/ui/switch";
import { todayInVietnam } from "@/lib/businessDate";
import { useRegistrationStatus, useSetExemption } from "@/features/admin/attendance/queries";
import { addDays, mondayOf } from "@bongcun/core/attendance";

const props = defineProps<{ branchId: string | undefined; canEdit: boolean }>();

// Any week lists the same people; next week is always inside the registration window.
const monday = addDays(mondayOf(todayInVietnam()), 7);
const query = useRegistrationStatus(computed(() => props.branchId), monday);
const rows = computed(() => query.data.value?.rows ?? []);
const mutation = useSetExemption();

const toggle = (userId: string, exempt: boolean) => {
  if (props.branchId) mutation.mutate({ branchId: props.branchId, userId, exempt });
};
</script>
