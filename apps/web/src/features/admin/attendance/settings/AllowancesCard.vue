<template>
  <section class="rounded-xl border bg-white p-4">
    <header class="mb-3 flex items-center justify-between gap-2">
      <h2 class="font-semibold">{{ $t("attendance.leave.allowancesTitle", { year }) }}</h2>
    </header>
    <p class="mb-3 text-sm text-muted-foreground">{{ $t("attendance.leave.allowancesHint") }}</p>
    <ul class="space-y-2">
      <AllowanceRow v-for="person in staff" :key="person.userId" :person="person" :year="year" :can-edit="canEdit" />
    </ul>
    <p v-if="!staff.length" class="text-sm text-muted-foreground">{{ $t("attendance.today.empty") }}</p>
  </section>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { todayInVietnam } from "@/lib/businessDate";
import { useShiftRoster } from "@/features/admin/attendance/queries";
import { addDays, mondayOf } from "@bongcun/core/attendance";
import AllowanceRow from "./AllowanceRow.vue";

const props = defineProps<{ branchId: string | undefined; canEdit: boolean }>();

const today = todayInVietnam();
const year = Number(today.slice(0, 4));
const monday = mondayOf(today);
const roster = useShiftRoster(computed(() => props.branchId), monday, addDays(monday, 6));
const staff = computed(() => roster.data.value?.staff ?? []);
</script>
