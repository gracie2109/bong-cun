<template>
  <AppDialog
    :open="open"
    :title="$t('medical.ward.logTitle', { name: row?.petName ?? '' })"
    :ok-text="$t('petCare.common.save')"
    :ok-disabled="!content.trim()"
    :busy="adding.isPending.value"
    form-id="ward-log-form"
    size="sm"
    @update:open="emit('update:open', $event)"
  >
    <form id="ward-log-form" class="space-y-3" @submit.prevent="submit">
      <Select v-model="kind">
        <SelectTrigger :aria-label="$t('medical.ward.logKind')"><SelectValue /></SelectTrigger>
        <SelectContent>
          <SelectItem v-for="item in KINDS" :key="item" :value="item">{{ $t(`medical.ward.logKinds.${item}`) }}</SelectItem>
        </SelectContent>
      </Select>
      <Textarea v-model="content" rows="3" :placeholder="$t(`medical.ward.logHint.${kind}`)" />
    </form>
  </AppDialog>
</template>

<script lang="ts" setup>
import { ref, watch } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { useAddLog } from "@/queries/inpatient";
import type { LogKind, WardRow } from "@/types/inpatient";

const KINDS: LogKind[] = ["vitals", "treatment", "note"];

const props = defineProps<{ open: boolean; row: WardRow | null }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const adding = useAddLog();
const kind = ref<LogKind>("vitals");
const content = ref("");
watch(() => props.open, (isOpen) => {
  if (!isOpen) return;
  kind.value = "vitals";
  content.value = "";
});

const submit = async () => {
  if (!props.row || !content.value.trim()) return;
  try {
    await adding.mutateAsync({ stayPetId: props.row.stayPetId, kind: kind.value, content: content.value.trim() });
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
