<template>
  <section class="space-y-2 rounded-lg border bg-muted/30 p-3 text-sm" aria-live="polite">
    <p v-if="error" class="font-semibold text-red-600">
      {{ error.hint ? $t(`boarding.errors.${error.hint}`, { name: error.name }) : error.message }}
    </p>
    <p v-else-if="!quote && !quoting" class="text-muted-foreground">{{ $t("boarding.dialog.quoteHint") }}</p>
    <p v-else-if="!quote" class="text-muted-foreground">{{ $t("boarding.dialog.quoting") }}</p>
    <template v-else>
      <ul class="divide-y">
        <li v-for="item in quote.items" :key="item.lineNo" class="flex items-start justify-between gap-3 py-1.5">
          <div class="min-w-0">
            <p class="font-medium">
              {{ item.petName }}
              <span class="text-muted-foreground">· {{ item.kennelTypeName }} {{ item.kennelCode }}</span>
            </p>
            <p class="text-xs text-muted-foreground">
              {{ $t("boarding.dialog.nightsAt", { nights: quote.nights, price: money(item.nightPrice) }) }}
              <template v-if="item.isExtraPet"> · {{ $t("boarding.dialog.sharedPrice") }}</template>
            </p>
            <p v-if="item.warnings.includes('overweight')" class="text-xs font-semibold text-amber-700">
              {{ $t("boarding.dialog.overweight") }}
            </p>
            <p v-if="item.warnings.includes('behavior')" class="text-xs font-semibold text-amber-700">
              {{ $t("boarding.dialog.behaviorNotes") }}
            </p>
          </div>
          <span class="shrink-0 font-semibold">{{ money(item.amount) }}</span>
        </li>
      </ul>
      <div class="flex items-center justify-between border-t pt-2 font-semibold">
        <span>{{ $t("boarding.dialog.estimate") }}</span>
        <span class="text-base text-primary">{{ money(quote.total) }}</span>
      </div>
    </template>
  </section>
</template>

<script lang="ts" setup>
import type { BoardingErrorHint } from "@bongcun/supabase/boarding";
import type { StayQuote } from "@bongcun/core/boarding";
import { money } from "../format";

defineProps<{
  quote: StayQuote | null;
  quoting: boolean;
  error: { hint: BoardingErrorHint | null; name: string; message: string } | null;
}>();
</script>
