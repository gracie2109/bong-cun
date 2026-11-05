<template>
  <li class="flex min-h-12 flex-wrap items-center gap-3 rounded-lg bg-muted/30 px-3 py-2 text-sm">
    <span class="min-w-0 flex-1 truncate font-medium">{{ person.name }}</span>
    <span v-if="balance" class="text-muted-foreground">{{ $t("attendance.leave.usedOf", { used: balance.used, pending: balance.pending }) }}</span>
    <Input v-model="days" type="number" min="0" max="60" step="0.5" inputmode="decimal" class="h-11 w-24" :disabled="!canEdit" />
    <Button v-if="canEdit" type="button" size="sm" variant="outline" class="min-h-11" :disabled="!changed || busy" @click="save">
      {{ $t("petCare.common.save") }}
    </Button>
  </li>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useLeaveBalance, useSaveAllowance } from "@/features/admin/attendance/queries";
import type { RosterStaff } from "@bongcun/core/attendance";

const props = defineProps<{ person: RosterStaff; year: number; canEdit: boolean }>();

const query = useLeaveBalance(computed(() => props.person.userId), computed(() => props.year));
const balance = computed(() => query.data.value);
const days = ref<string | number>("");
watch(balance, (value) => (days.value = value?.allowance ?? ""), { immediate: true });

const changed = computed(() => balance.value !== undefined && Number(days.value) !== balance.value.allowance && days.value !== "");
const mutation = useSaveAllowance();
const busy = mutation.isPending;
const save = () => mutation.mutate({ userId: props.person.userId, year: props.year, days: Number(days.value) });
</script>
