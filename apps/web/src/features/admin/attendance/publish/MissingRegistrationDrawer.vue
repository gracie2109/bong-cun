<template>
  <Sheet :open="open" @update:open="emit('update:open', $event)">
    <SheetContent side="right" class="flex w-full flex-col gap-0 p-0 sm:max-w-md">
      <SheetHeader class="border-b p-4">
        <SheetTitle>{{ $t("attendance.publish.missing.title") }}</SheetTitle>
        <SheetDescription>{{ description }}</SheetDescription>
      </SheetHeader>
      <ul class="flex-1 divide-y overflow-y-auto">
        <MissingRegistrationRow
          v-for="row in rows"
          :key="row.userId"
          :row="row"
          :can-assign="canAssign"
          :busy="assigning"
          @like-last-week="assign(row.userId)"
        />
        <li v-if="!rows.length" class="px-4 py-6 text-center text-sm text-muted-foreground">{{ $t("attendance.publish.missing.empty") }}</li>
      </ul>
    </SheetContent>
  </Sheet>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle } from "@/components/ui/sheet";
import { useAssignLikeLastWeek, useRegistrationStatus } from "@/features/admin/attendance/queries";
import MissingRegistrationRow from "./MissingRegistrationRow.vue";

const props = defineProps<{ open: boolean; branchId: string | undefined; monday: string; canAssign: boolean }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const { t } = useI18n();
const query = useRegistrationStatus(
  computed(() => props.branchId),
  computed(() => props.monday),
  computed(() => props.open)
);
const rows = computed(() => (query.data.value?.rows ?? []).filter((row) => row.mustRegister));
const description = computed(() => {
  const closes = query.data.value?.closesAt;
  return closes ? t("attendance.publish.missing.closes", { at: new Date(closes).toLocaleString("vi-VN") }) : t("attendance.publish.missing.hint");
});

const mutation = useAssignLikeLastWeek();
const assigning = mutation.isPending;
const assign = (userId: string) => {
  if (props.branchId) mutation.mutate({ branchId: props.branchId, monday: props.monday, userId });
};
</script>
