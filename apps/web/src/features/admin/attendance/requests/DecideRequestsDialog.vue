<template>
  <AppDialog
    :open="open"
    :title="$t('attendance.requests.decideTitle', { count: ids.length })"
    :description="description"
    :hide-footer="true"
    @update:open="emit('update:open', $event)"
  >
    <div class="space-y-4">
      <slot />
      <div class="space-y-1">
        <Label for="dr-note">{{ $t("attendance.requests.note") }}</Label>
        <Input id="dr-note" v-model="note" maxlength="300" />
        <p class="text-xs text-muted-foreground">{{ $t("attendance.confirm.recorded") }}</p>
      </div>

      <ul v-if="failed.length" class="space-y-1 rounded-lg border border-destructive/40 bg-red-50 p-3 text-sm text-red-900">
        <li v-for="item in failed" :key="item.id">{{ nameOf(item.id) }}: {{ $te(`attendance.errors.${item.hint}`) ? $t(`attendance.errors.${item.hint}`) : item.hint }}</li>
      </ul>

      <div class="flex flex-wrap justify-end gap-2">
        <Button type="button" variant="outline" class="min-h-11 text-destructive" :disabled="busy" @click="decide(false)">{{ $t("attendance.leave.reject") }}</Button>
        <Button type="button" class="min-h-11" :disabled="busy" @click="decide(true)">{{ $t("attendance.leave.approve") }}</Button>
      </div>
    </div>
  </AppDialog>
</template>

<script lang="ts" setup>
import { ref, watch } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useDecideShiftRequests } from "@/features/admin/attendance/queries";

const props = defineProps<{
  open: boolean;
  ids: string[];
  description?: string;
  /** Shown beside a failure so the manager knows which request it was. */
  names?: Record<string, string>;
}>();
const emit = defineEmits<{ "update:open": [boolean]; done: [] }>();

const mutation = useDecideShiftRequests();
const busy = mutation.isPending;
const note = ref("");
const failed = ref<{ id: string; hint: string }[]>([]);

watch(
  () => props.open,
  (isOpen) => {
    if (!isOpen) return;
    note.value = "";
    failed.value = [];
  }
);

const nameOf = (id: string) => props.names?.[id] ?? "";

const decide = async (approve: boolean) => {
  try {
    const result = await mutation.mutateAsync({ ids: props.ids, approve, note: note.value.trim() || null });
    failed.value = result.failed;
    emit("done");
    if (!result.failed.length) emit("update:open", false);
  } catch {
    // the mutation already showed why
  }
};
</script>
