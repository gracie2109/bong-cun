<template>
  <section class="rounded-xl border bg-white">
    <header class="flex items-center justify-between gap-3 border-b px-4 py-3">
      <div>
        <h2 class="font-semibold">{{ $t("spa.settings.hours") }}</h2>
        <p class="text-xs text-muted-foreground">{{ $t("spa.settings.hoursHint") }}</p>
      </div>
      <Button v-if="canEdit" size="sm" :disabled="!dirty || mutation.isPending.value" @click="save">
        <Loader2 v-if="mutation.isPending.value" class="mr-1 size-4 animate-spin" />
        {{ $t("petCare.common.save") }}
      </Button>
    </header>

    <ul class="divide-y">
      <li v-for="day in days" :key="day.weekday" class="flex flex-wrap items-center gap-3 px-4 py-2.5">
        <span class="w-24 text-sm font-medium">{{ $t(`spa.weekdays.${day.weekday}`) }}</span>
        <Switch
          :model-value="!day.isClosed"
          :disabled="!canEdit"
          :aria-label="$t('spa.settings.open')"
          @update:model-value="(value: boolean) => (day.isClosed = !value)"
        />
        <template v-if="!day.isClosed">
          <Input v-model="day.openTime" type="time" step="900" class="h-9 w-28" :disabled="!canEdit" />
          <span class="text-muted-foreground">–</span>
          <Input v-model="day.closeTime" type="time" step="900" class="h-9 w-28" :disabled="!canEdit" />
        </template>
        <span v-else class="text-sm text-muted-foreground">{{ $t("spa.settings.closed") }}</span>
      </li>
    </ul>
  </section>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { Loader2 } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Switch } from "@/components/ui/switch";
import { useSaveWeekHours, useWeekHours } from "@/queries/spa";
import type { DayHours } from "@/repositories/spa";

const props = defineProps<{ branchId: string | undefined; canEdit: boolean }>();

const query = useWeekHours(computed(() => props.branchId));
const mutation = useSaveWeekHours();

const days = ref<DayHours[]>([]);
const saved = ref("");

// Start from what the database has; a branch switch or a refetch resets the form.
watch(
  () => query.data.value,
  (data) => {
    days.value = (data ?? []).map((day) => ({ ...day }));
    saved.value = JSON.stringify(days.value);
  },
  { immediate: true }
);

const dirty = computed(() => JSON.stringify(days.value) !== saved.value);

const save = () => {
  if (!props.branchId) return;
  mutation.mutate({ branchId: props.branchId, hours: days.value });
};
</script>
