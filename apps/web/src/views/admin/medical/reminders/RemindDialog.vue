<template>
  <AppDialog
    :open="open"
    :title="$t('medical.reminders.markTitle', { pet: reminder?.petName ?? '' })"
    :description="$t('medical.reminders.markDesc')"
    :ok-text="$t('medical.reminders.mark')"
    :busy="busy"
    form-id="medical-remind-form"
    size="sm"
    @update:open="emit('update:open', $event)"
  >
    <form id="medical-remind-form" class="space-y-1.5" @submit.prevent="emit('confirm', note.trim())">
      <Label for="remind-note">{{ $t("medical.reminders.note") }}</Label>
      <Textarea id="remind-note" v-model="note" rows="3" :placeholder="$t('medical.reminders.noteHint')" />
    </form>
  </AppDialog>
</template>

<script lang="ts" setup>
import { ref, watch } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import type { Reminder } from "@bongcun/core/medical";

const props = defineProps<{ open: boolean; reminder: Reminder | null; busy: boolean }>();
const emit = defineEmits<{ "update:open": [value: boolean]; confirm: [note: string] }>();

const note = ref("");
watch(() => props.open, (isOpen) => isOpen && (note.value = ""));
</script>
