<template>
  <li class="space-y-3 rounded-xl border bg-white p-4">
    <div class="flex flex-wrap items-start justify-between gap-2">
      <div>
        <p class="font-mono text-sm font-semibold">{{ appointment.code }}</p>
        <p class="font-semibold">{{ dayLabel(startDay, locale) }}</p>
        <p class="text-sm text-primary">{{ rangeLabel(appointment.startAt, minutes) }}</p>
      </div>
      <span class="rounded-full px-2.5 py-0.5 text-xs font-semibold" :class="STATUS_TONE[appointment.status] ?? 'bg-muted text-muted-foreground'">
        {{ $t(`client.appointments.status.${appointment.status}`) }}
      </span>
    </div>

    <p class="text-sm text-muted-foreground">{{ appointment.branchName }}</p>

    <ul class="divide-y rounded-lg border text-sm">
      <li
        v-for="(item, index) in appointment.items"
        :key="index"
        class="flex items-start justify-between gap-3 px-3 py-2"
        :class="item.status === 'cancelled' && 'text-muted-foreground line-through'"
      >
        <span><span class="font-medium">{{ item.petName }}</span> · {{ item.name }}</span>
        <span v-if="item.estPrice !== null" class="shrink-0">{{ formatPrice(item.estPrice) }}</span>
      </li>
    </ul>

    <div class="flex flex-wrap items-center justify-between gap-2">
      <p class="text-sm">
        {{ $t("client.booking.estimate") }}:
        <span class="font-semibold text-primary">{{ formatPrice(appointment.estTotal) }}{{ appointment.hasUnpriced ? "+" : "" }}</span>
      </p>
      <Button v-if="appointment.canCancel" size="sm" variant="outline" class="text-red-600" :disabled="busy" @click="emit('cancel')">
        {{ $t("client.appointments.cancel") }}
      </Button>
      <p v-else-if="appointment.status === 'booked'" class="text-xs text-muted-foreground">
        {{ $t("client.appointments.callToCancel") }}
        <a v-if="appointment.branchPhone" :href="`tel:${appointment.branchPhone}`" class="font-medium text-primary">{{ appointment.branchPhone }}</a>
      </p>
    </div>
  </li>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import { Button } from "@/components/ui/button";
import { formatPrice } from "@/lib/utils";
import type { MyAppointment } from "@bongcun/core/account";
import { businessDate, dayLabel, rangeLabel } from "@/utils/spa/booking";

const STATUS_TONE: Record<string, string> = {
  booked: "bg-sky-100 text-sky-700",
  checked_in: "bg-amber-100 text-amber-700",
  in_progress: "bg-amber-100 text-amber-700",
  done: "bg-green-100 text-green-700",
  paid: "bg-green-100 text-green-700",
  cancelled: "bg-muted text-muted-foreground",
  no_show: "bg-red-100 text-red-700",
};

const props = defineProps<{ appointment: MyAppointment; busy: boolean }>();
const emit = defineEmits<{ cancel: [] }>();

const { locale } = useI18n();
const startDay = computed(() => businessDate(new Date(props.appointment.startAt)));
const minutes = computed(() => Math.round((new Date(props.appointment.endAt).getTime() - new Date(props.appointment.startAt).getTime()) / 60000));
</script>
