<template>
  <section class="rounded-xl border bg-white">
    <header class="flex items-center justify-between gap-3 border-b px-4 py-3">
      <div>
        <h2 class="font-semibold">{{ $t("attendance.rules.title") }}</h2>
        <p class="text-xs text-muted-foreground">{{ $t("attendance.rules.hint") }}</p>
      </div>
      <Button v-if="canEdit" size="sm" :disabled="!dirty || !valid || saving" @click="save">
        <Loader2 v-if="saving" class="mr-1 size-4 animate-spin" />
        {{ $t("petCare.common.save") }}
      </Button>
    </header>

    <div v-if="rules" class="grid gap-4 p-4 sm:grid-cols-2 xl:grid-cols-3">
      <div v-for="field in NUMBER_FIELDS" :key="field.key" class="space-y-1">
        <Label :for="`rule-${field.key}`">{{ $t(`attendance.rules.${field.key}`) }}</Label>
        <Input :id="`rule-${field.key}`" v-model.number="rules[field.key]" type="number" :min="field.min" :max="field.max" step="1" inputmode="numeric" :disabled="!canEdit" />
        <p class="text-xs text-muted-foreground">{{ $t(`attendance.rules.${field.key}Hint`) }}</p>
      </div>
      <div class="flex items-start justify-between gap-3 rounded-lg border p-3 sm:col-span-2 xl:col-span-3">
        <div>
          <Label for="rule-allow-unscheduled">{{ $t("attendance.rules.allowUnscheduled") }}</Label>
          <p class="text-xs text-muted-foreground">{{ $t("attendance.rules.allowUnscheduledHint") }}</p>
        </div>
        <Switch id="rule-allow-unscheduled" v-model:checked="rules.allowUnscheduled" :disabled="!canEdit" />
      </div>
    </div>
    <p v-else-if="!loading" class="px-4 py-6 text-center text-sm text-muted-foreground">{{ $t("attendance.rules.unavailable") }}</p>
    <p v-if="rules && !valid" class="px-4 pb-4 text-sm text-destructive">{{ $t("attendance.errors.bad_input") }}</p>
  </section>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Loader2 } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { useAttendanceRulesForm } from "./useAttendanceRulesForm";

const props = defineProps<{ branchId: string | undefined; canEdit: boolean }>();

/** The numeric rules, with the range the database accepts. */
const NUMBER_FIELDS = [
  { key: "lateGraceMinutes", min: 0, max: 60 },
  { key: "earlyGraceMinutes", min: 0, max: 60 },
  { key: "checkinEarlyMinutes", min: 0, max: 240 },
  { key: "overtimeMinMinutes", min: 0, max: 240 },
  { key: "reviewAfterHours", min: 4, max: 24 },
] as const;

const { rules, dirty, valid, save, saving, loading } = useAttendanceRulesForm(computed(() => props.branchId));
</script>
