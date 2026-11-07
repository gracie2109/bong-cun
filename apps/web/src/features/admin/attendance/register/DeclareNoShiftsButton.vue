<template>
  <div class="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-dashed bg-white px-4 py-3">
    <p class="text-sm text-muted-foreground">{{ $t("attendance.register.declareHint") }}</p>
    <Button size="sm" variant="outline" class="min-h-9" @click="ask">
      <CalendarOff class="mr-1 size-4" />
      {{ $t("attendance.register.declare") }}
    </Button>
  </div>
  <ConfirmReasonDialog :confirm="confirm" />
</template>

<script lang="ts" setup>
import { CalendarOff } from "lucide-vue-next";
import { useI18n } from "vue-i18n";
import ConfirmReasonDialog from "@/components/common/ConfirmReasonDialog.vue";
import { useConfirmAction } from "@/components/common/useConfirmAction";
import { Button } from "@/components/ui/button";

const emit = defineEmits<{ declare: [reason: string | null] }>();
const { t } = useI18n();
const confirm = useConfirmAction();

const ask = async () => {
  const answer = await confirm.ask({
    title: t("attendance.register.declareConfirm.title"),
    message: t("attendance.register.declareConfirm.message"),
    okText: t("attendance.register.declare"),
    reason: { label: t("attendance.register.declareConfirm.reason"), placeholder: t("attendance.register.declareConfirm.reasonHint") },
  });
  if (answer.ok) emit("declare", answer.reason);
};
</script>
