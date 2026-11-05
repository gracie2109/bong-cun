<template>
  <section v-if="items.length" class="rounded-xl border border-amber-300 bg-amber-50 p-3">
    <h2 class="mb-2 flex items-center gap-2 text-sm font-semibold text-amber-900">
      <TriangleAlert class="size-4" />
      {{ $t("attendance.today.reviewTitle", { count: items.length }) }}
    </h2>
    <ul class="space-y-2">
      <li v-for="item in items" :key="item.entryId" class="flex flex-wrap items-center gap-x-3 gap-y-1 rounded-lg bg-white px-3 py-2 text-sm">
        <span class="font-semibold">{{ item.userName }}</span>
        <span class="text-muted-foreground">{{ dayMonth(item.workDate) }} · {{ timeOf(item.checkInAt) }}<template v-if="item.checkOutAt">–{{ timeOf(item.checkOutAt) }}</template></span>
        <span class="text-amber-800">{{ $t(`attendance.today.reason_${item.reason}`) }}</span>
        <span v-if="canEdit" class="ml-auto flex gap-2">
          <Button type="button" size="sm" variant="outline" class="min-h-9" @click="emit('edit', item.entryId)">{{ $t("attendance.today.fix") }}</Button>
          <Button type="button" size="sm" variant="ghost" class="min-h-9" @click="emit('reviewed', item.entryId)">
            <Check class="mr-1 size-3.5" />
            {{ $t("attendance.today.markReviewed") }}
          </Button>
        </span>
      </li>
    </ul>
  </section>
</template>

<script lang="ts" setup>
import { Check, TriangleAlert } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { dayMonth, timeOf } from "@/features/admin/attendance/shared/attendanceFormat";
import type { ReviewItem } from "@bongcun/core/attendance";

defineProps<{ items: ReviewItem[]; canEdit: boolean }>();
const emit = defineEmits<{ edit: [entryId: string]; reviewed: [entryId: string] }>();
</script>
