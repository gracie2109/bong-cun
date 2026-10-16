<template>
  <AppDialog
    :open="open"
    :title="$t('medical.cancel.title', { code })"
    :description="$t('medical.cancel.desc')"
    :ok-text="$t('medical.cancel.confirm')"
    :busy="busy"
    form-id="medical-cancel-form"
    size="sm"
    danger
    @update:open="emit('update:open', $event)"
  >
    <form id="medical-cancel-form" class="space-y-1.5" @submit.prevent="emit('confirm', reason.trim())">
      <Label for="medical-cancel-reason">{{ $t("medical.cancel.reason") }}</Label>
      <Textarea id="medical-cancel-reason" v-model="reason" rows="3" />
    </form>
  </AppDialog>
</template>

<script lang="ts" setup>
import { ref, watch } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

const props = defineProps<{ open: boolean; code: string; busy: boolean }>();
const emit = defineEmits<{ "update:open": [value: boolean]; confirm: [reason: string] }>();

const reason = ref("");
watch(() => props.open, (isOpen) => isOpen && (reason.value = ""));
</script>
