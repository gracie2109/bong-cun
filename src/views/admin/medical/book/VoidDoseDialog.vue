<template>
  <AppDialog
    :open="open"
    :title="$t('medical.book.voidTitle')"
    :description="$t('medical.book.voidDesc')"
    :ok-text="$t('medical.book.void')"
    :busy="busy"
    form-id="medical-void-form"
    size="sm"
    danger
    @update:open="emit('update:open', $event)"
  >
    <form id="medical-void-form" class="space-y-1.5" @submit.prevent="emit('confirm', reason.trim())">
      <Label for="medical-void-reason">{{ $t("medical.cancel.reason") }}</Label>
      <Textarea id="medical-void-reason" v-model="reason" rows="3" />
    </form>
  </AppDialog>
</template>

<script lang="ts" setup>
import { ref, watch } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

const props = defineProps<{ open: boolean; busy: boolean }>();
const emit = defineEmits<{ "update:open": [value: boolean]; confirm: [reason: string] }>();

const reason = ref("");
watch(() => props.open, (isOpen) => isOpen && (reason.value = ""));
</script>
