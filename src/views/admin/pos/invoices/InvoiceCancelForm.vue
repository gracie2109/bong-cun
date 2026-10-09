<template>
  <div class="space-y-2 rounded-lg border border-red-200 p-3">
    <Label for="cancel-reason">{{ $t("pos.invoices.cancelReason") }}</Label>
    <Textarea id="cancel-reason" v-model="reason" rows="2" class="resize-none" />
    <div class="flex justify-end gap-2">
      <Button variant="outline" size="sm" @click="emit('dismiss')">{{ $t("petCare.common.cancel") }}</Button>
      <Button variant="destructive" size="sm" :disabled="!reason.trim() || pending" @click="emit('confirm')">
        {{ $t("pos.invoices.confirmCancel") }}
      </Button>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

defineProps<{ pending: boolean }>();

const emit = defineEmits<{ dismiss: []; confirm: [] }>();

const reason = defineModel<string>("reason", { required: true });
</script>
