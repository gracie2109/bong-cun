<template>
  <AppDialog
    :open="confirm.open.value"
    :title="confirm.options.value.title"
    :description="confirm.options.value.message"
    :ok-text="confirm.options.value.okText"
    :danger="confirm.options.value.danger"
    size="sm"
    @update:open="onOpenChange"
    @ok="confirm.settle(true, reason)"
    @cancel="confirm.settle(false)"
  >
    <div v-if="confirm.options.value.reason" class="space-y-1">
      <Label for="confirm-reason">{{ confirm.options.value.reason.label }}</Label>
      <Textarea id="confirm-reason" v-model="reason" rows="2" maxlength="300" :placeholder="confirm.options.value.reason.placeholder" />
    </div>
  </AppDialog>
</template>

<script lang="ts" setup>
import { ref, watch } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import type { ConfirmAction } from "./useConfirmAction";

/** The dialog for `useConfirmAction`: a question, an optional reason box, OK and Cancel. */
const props = defineProps<{ confirm: ConfirmAction }>();

const reason = ref("");
watch(
  () => props.confirm.open.value,
  (isOpen) => {
    if (isOpen) reason.value = "";
  }
);

const onOpenChange = (value: boolean) => {
  if (!value) props.confirm.settle(false);
};
</script>
