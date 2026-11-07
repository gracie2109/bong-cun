<template>
  <div class="sticky bottom-0 z-20 flex flex-wrap items-center gap-3 rounded-xl border bg-white p-3 shadow-sm">
    <p class="text-sm font-semibold">{{ $t("attendance.register.selected", { count }) }}</p>
    <Input v-model="note" maxlength="300" class="min-w-48 flex-1" :placeholder="$t('attendance.register.notePlaceholder')" />
    <p v-if="overQuota" class="w-full text-sm text-destructive">{{ $t("attendance.errors.over_weekly_limit") }}</p>
    <Button type="button" variant="ghost" :disabled="!count || sending" @click="emit('clear')">{{ $t("attendance.register.clear") }}</Button>
    <Button type="button" class="min-h-11" :disabled="!count || sending || overQuota" @click="emit('send')">
      <Loader2 v-if="sending" class="mr-1 size-4 animate-spin" />
      {{ $t("attendance.register.send") }}
    </Button>
  </div>
</template>

<script lang="ts" setup>
import { Loader2 } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

defineProps<{ count: number; sending: boolean; overQuota: boolean }>();
const note = defineModel<string>("note", { required: true });
const emit = defineEmits<{ send: []; clear: [] }>();
</script>
