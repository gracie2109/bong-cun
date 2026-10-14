<template>
  <div class="space-y-4">
    <div class="rounded-xl border bg-white p-4">
      <p class="text-sm text-muted-foreground">{{ branchName }}</p>
      <p class="font-semibold">{{ dayLabel(date, locale) }}</p>
      <p class="text-lg font-bold text-primary">{{ rangeLabel(startAt, quote.totalMinutes) }}</p>
    </div>

    <ul class="divide-y rounded-xl border bg-white">
      <li v-for="(line, index) in quote.lines" :key="index" class="flex items-start justify-between gap-3 p-3 text-sm">
        <span class="min-w-0">
          <span class="block font-medium">{{ line.name }}</span>
          <span class="block text-xs text-muted-foreground">{{ petName(line.petId) }} · {{ duration(line.minutes) }}</span>
        </span>
        <span v-if="line.price !== null" class="shrink-0 font-semibold">{{ formatPrice(line.price) }}</span>
        <span v-else class="shrink-0 text-xs text-muted-foreground">{{ $t("client.booking.quoteOnArrival") }}</span>
      </li>
      <li class="flex items-center justify-between gap-3 bg-muted/40 p-3 text-sm font-semibold">
        <span>{{ $t("client.booking.estimate") }}</span>
        <span class="text-primary">{{ formatPrice(quote.totalPrice) }}{{ quote.hasUnpriced ? "+" : "" }}</span>
      </li>
    </ul>
    <p class="text-xs text-muted-foreground">{{ $t("client.booking.confirmNote") }}</p>

    <div class="space-y-1.5">
      <Label for="booking-note">{{ $t("client.booking.note") }}</Label>
      <Textarea id="booking-note" v-model="note" rows="2" maxlength="500" :placeholder="$t('client.booking.noteHint')" />
    </div>
  </div>
</template>

<script lang="ts" setup>
import { useI18n } from "vue-i18n";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { useDurationLabel } from "@/composables/spa/useDurationLabel";
import { formatPrice } from "@/lib/utils";
import type { MyPet } from "@/types/account";
import type { WebQuote } from "@/types/spaWeb";
import { dayLabel, rangeLabel } from "@/utils/spa/booking";

const props = defineProps<{ branchName: string; date: string; startAt: string; quote: WebQuote; pets: MyPet[] }>();
const note = defineModel<string>("note", { required: true });

const { locale } = useI18n();
const duration = useDurationLabel();
const petName = (id: string) => props.pets.find((pet) => pet.id === id)?.name ?? "";
</script>
