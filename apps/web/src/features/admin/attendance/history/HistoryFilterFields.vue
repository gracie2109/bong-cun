<template>
  <div class="flex flex-wrap items-center gap-2">
    <Input v-model="from" type="date" class="h-11 w-40" :aria-label="$t('attendance.history.from')" />
    <Input v-model="to" type="date" class="h-11 w-40" :min="from" :aria-label="$t('attendance.history.to')" />
    <select v-model="userId" class="h-11 rounded-md border bg-white px-3 text-sm" :aria-label="$t('attendance.history.person')">
      <option value="">{{ $t("attendance.history.allPeople") }}</option>
      <option v-for="person in staff" :key="person.userId" :value="person.userId">{{ person.name }}</option>
    </select>
    <select v-model="entity" class="h-11 rounded-md border bg-white px-3 text-sm" :aria-label="$t('attendance.history.kind')">
      <option value="">{{ $t("attendance.history.allKinds") }}</option>
      <option v-for="item in HISTORY_ENTITIES" :key="item" :value="item">{{ $t(`attendance.history.entities.${item}`) }}</option>
    </select>
    <label class="flex items-center gap-2 text-sm text-muted-foreground">
      <Switch v-model:checked="publishedOnly" />
      {{ $t("attendance.history.publishedOnly") }}
    </label>
  </div>
</template>

<script lang="ts" setup>
import { Input } from "@/components/ui/input";
import { Switch } from "@/components/ui/switch";
import { HISTORY_ENTITIES } from "@bongcun/core/attendance";
import type { HistoryEntity, RosterStaff } from "@bongcun/core/attendance";

defineProps<{ staff: RosterStaff[] }>();
const from = defineModel<string>("from", { required: true });
const to = defineModel<string>("to", { required: true });
const userId = defineModel<string>("userId", { required: true });
const entity = defineModel<HistoryEntity | "">("entity", { required: true });
const publishedOnly = defineModel<boolean>("publishedOnly", { required: true });
</script>
