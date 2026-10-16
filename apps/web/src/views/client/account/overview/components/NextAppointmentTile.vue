<template>
  <RouterLink
    :to="{ name: appointment ? 'account-appointments' : 'spa-book' }"
    class="flex items-center gap-3 rounded-xl border bg-white p-4 transition-colors hover:bg-muted/40"
  >
    <span class="flex size-10 items-center justify-center rounded-full bg-primary/10 text-primary">
      <CalendarClock class="size-5" />
    </span>
    <span class="min-w-0">
      <span class="block text-sm font-semibold">{{ $t("client.account.overview.nextAppointment") }}</span>
      <span v-if="appointment" class="block truncate text-xs text-muted-foreground">
        {{ dayLabel(day, locale) }} · {{ slotTimeLabel(appointment.startAt) }} · {{ appointment.code }}
      </span>
      <span v-else class="block text-xs text-muted-foreground">{{ $t("client.account.overview.noAppointment") }}</span>
    </span>
  </RouterLink>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import { CalendarClock } from "lucide-vue-next";
import type { MyAppointment } from "@bongcun/core/account";
import { businessDate, dayLabel, slotTimeLabel } from "@/utils/spa/booking";

const props = defineProps<{ appointment: MyAppointment | null }>();

const { locale } = useI18n();
const day = computed(() => (props.appointment ? businessDate(new Date(props.appointment.startAt)) : ""));
</script>
