<template>
  <AppDialog
    v-model:open="open"
    :title="$t('shop.order.cancelTitle')"
    :description="$t('shop.order.cancelHint')"
    :ok-text="$t('shop.order.cancelOk')"
    :cancel-text="$t('shop.order.cancelKeep')"
    :busy="busy"
    danger
    @ok="$emit('confirm')"
  >
    <div class="space-y-1.5">
      <Label for="cancel-reason">{{ $t("shop.order.cancelReason") }}</Label>
      <Textarea id="cancel-reason" v-model="reason" rows="3" maxlength="300" />
    </div>
  </AppDialog>
</template>

<script lang="ts" setup>
import AppDialog from "@/components/common/AppDialog.vue";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

const open = defineModel<boolean>("open", { required: true });
const reason = defineModel<string>("reason", { required: true });
defineProps<{ busy: boolean }>();
defineEmits<{ confirm: [] }>();
</script>
