<template>
  <div class="space-y-4">
    <div class="flex flex-wrap items-end gap-4">
      <div class="space-y-1.5">
        <Label for="booking-date">{{ $t("client.booking.date") }}</Label>
        <Input id="booking-date" v-model="date" type="date" :min="minDate" :max="maxDate" class="h-11 w-52 rounded-xl" />
      </div>
      <p class="pb-2 text-sm text-muted-foreground">{{ $t("client.booking.needTime", { time: duration(totalMinutes) }) }}</p>
    </div>

    <p class="text-sm font-semibold">{{ dayLabel(date, locale) }}</p>
    <div v-if="loading" class="grid grid-cols-3 gap-2 sm:grid-cols-5 md:grid-cols-6" aria-hidden="true">
      <div v-for="n in 12" :key="n" class="shop-skeleton h-10 rounded-full" />
    </div>
    <p v-else-if="slots.length === 0" class="rounded-2xl border border-dashed py-8 text-center text-sm text-muted-foreground">
      {{ $t("client.booking.noSlots") }}
    </p>
    <p v-else-if="!hasFree" class="rounded-2xl border border-dashed py-8 text-center text-sm text-muted-foreground">
      {{ $t("client.booking.dayFull") }}
    </p>
    <div v-else class="grid grid-cols-3 gap-2 sm:grid-cols-5 md:grid-cols-6">
      <Button
        v-for="slot in slots"
        :key="slot.startAt"
        type="button"
        variant="outline"
        class="h-10 rounded-full font-semibold tabular-nums"
        :class="[slot.startAt === selected && 'border-sage bg-sage text-white hover:bg-sage/90 hover:text-white', !slot.free && 'line-through opacity-40']"
        :aria-pressed="slot.startAt === selected"
        :disabled="!slot.free"
        @click="emit('pick', slot.startAt)"
      >
        {{ slotTimeLabel(slot.startAt) }}
      </Button>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useDurationLabel } from "@/composables/spa/useDurationLabel";
import type { BookingRules, SpaSlot } from "@bongcun/core/spa";
import { businessDate, dayLabel, slotTimeLabel } from "@bongcun/core/spa";

const props = defineProps<{
  slots: SpaSlot[];
  loading: boolean;
  selected: string | null;
  totalMinutes: number;
  rules: BookingRules;
}>();
const emit = defineEmits<{ pick: [startAt: string] }>();

const date = defineModel<string>("date", { required: true });

const { locale } = useI18n();
const duration = useDurationLabel();
const minDate = businessDate();
const maxDate = computed(() => businessDate(new Date(), props.rules.maxDays));
const hasFree = computed(() => props.slots.some((slot) => slot.free));
</script>
