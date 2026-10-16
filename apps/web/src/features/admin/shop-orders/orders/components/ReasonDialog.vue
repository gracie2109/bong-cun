<template>
  <AppDialog
    v-model:open="open"
    :title="$t(`shop.admin.dialogs.${kind}Title`)"
    :description="$t(`shop.admin.dialogs.${kind}Hint`)"
    :ok-text="$t(`shop.admin.dialogs.${kind}Ok`)"
    :ok-disabled="!reason.trim()"
    :busy="busy"
    danger
    @ok="$emit('submit')"
  >
    <div class="space-y-1.5">
      <Label for="step-reason">{{ $t("shop.admin.reason") }}</Label>
      <Textarea id="step-reason" v-model="reason" rows="3" maxlength="300" />
    </div>
  </AppDialog>
</template>

<script lang="ts" setup>
import AppDialog from "@/components/common/AppDialog.vue";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

const open = defineModel<boolean>("open", { required: true });
const reason = defineModel<string>("reason", { required: true });
defineProps<{ kind: "return" | "cancel"; busy: boolean }>();
defineEmits<{ submit: [] }>();
</script>
