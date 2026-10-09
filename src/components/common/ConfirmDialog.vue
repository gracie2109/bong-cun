<template>
  <AppDialog
    :open="open"
    :title="title"
    :description="desc"
    :ok-text="okBtn"
    :cancel-text="cancelBtn"
    :danger="danger"
    size="sm"
    @update:open="(value) => !value && $emit('openChange')"
    @ok="onOk"
    @cancel="$emit('cancel')"
  />
</template>

<script setup lang="ts">
import AppDialog from "./AppDialog.vue";

/** A yes/no question; built on `AppDialog`, so Esc cancels, Enter confirms and the corner button closes it. */
defineProps<{
  open: boolean;
  title: string;
  desc?: string;
  okBtn?: string;
  cancelBtn?: string;
  /** A red confirm button, for deleting or cancelling something. */
  danger?: boolean;
}>();

const emit = defineEmits(["cancel", "openChange", "handleOk"]);

const onOk = () => {
  emit("handleOk");
  emit("openChange");
};
</script>
