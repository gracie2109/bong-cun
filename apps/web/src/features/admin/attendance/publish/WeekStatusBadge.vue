<template>
  <span
    v-if="week.requirePublish"
    class="inline-flex min-h-8 items-center gap-1 rounded-full px-3 text-xs font-semibold"
    :class="week.status === 'published' ? 'bg-emerald-50 text-emerald-800' : 'bg-amber-50 text-amber-900'"
  >
    <component :is="week.status === 'published' ? CircleCheck : FilePen" class="size-3.5" aria-hidden="true" />
    {{ week.status === "published" ? $t("attendance.publish.published") : $t("attendance.publish.draft") }}
    <span v-if="week.status === 'published' && week.autoPublished" class="font-normal">· {{ $t("attendance.publish.auto") }}</span>
  </span>
</template>

<script lang="ts" setup>
import { CircleCheck, FilePen } from "lucide-vue-next";
import type { WeekStatus } from "@bongcun/core/attendance";

defineProps<{ week: WeekStatus }>();
</script>
