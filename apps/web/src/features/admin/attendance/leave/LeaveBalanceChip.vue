<template>
  <p v-if="balance" class="rounded-lg border bg-muted/30 px-3 py-2 text-sm">
    {{ $t("attendance.leave.balance", { remaining: balance.remaining, allowance: balance.allowance, pending: balance.pending }) }}
  </p>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useLeaveBalance } from "@/features/admin/attendance/queries";

const props = defineProps<{ userId: string | undefined; year: number }>();
const query = useLeaveBalance(computed(() => props.userId), computed(() => props.year));
const balance = computed(() => query.data.value);
</script>
