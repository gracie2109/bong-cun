<template>
  <AppDialog
    :open="open"
    :title="$t('attendance.history.cellTitle')"
    :description="description"
    size="lg"
    hide-cancel
    :ok-text="$t('attendance.register.close')"
    @update:open="emit('update:open', $event)"
    @ok="emit('update:open', false)"
  >
    <p v-if="query.isPending.value" class="text-sm text-muted-foreground">…</p>
    <ul v-else class="space-y-2">
      <HistoryRow v-for="row in rows" :key="row.id" :row="row" />
      <li v-if="!rows.length" class="text-sm text-muted-foreground">{{ $t("attendance.history.empty") }}</li>
    </ul>
  </AppDialog>
</template>

<script lang="ts" setup>
import { computed, toRef } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import { useScheduleHistoryOf } from "@/features/admin/attendance/queries";
import HistoryRow from "./HistoryRow.vue";

const props = defineProps<{ open: boolean; entity: string; entityId: string | undefined; description?: string }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const query = useScheduleHistoryOf(toRef(props, "entity"), toRef(props, "entityId"), toRef(props, "open"));
const rows = computed(() => query.data.value ?? []);
</script>
