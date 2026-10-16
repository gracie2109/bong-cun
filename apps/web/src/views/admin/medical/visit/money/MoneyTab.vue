<template>
  <div class="space-y-4">
    <div class="grid gap-3 sm:grid-cols-3">
      <div v-for="card in cards" :key="card.label" class="rounded-lg border p-3">
        <p class="text-xs text-muted-foreground">{{ card.label }}</p>
        <p class="text-lg font-bold" :class="card.tone">{{ money(card.value) }}</p>
      </div>
    </div>

    <p v-if="rows.length === 0" class="rounded-lg border border-dashed p-8 text-center text-sm text-muted-foreground">
      {{ $t("medical.money.empty") }}
    </p>
    <ul v-else class="divide-y rounded-lg border text-sm">
      <li v-for="row in rows" :key="row.id" class="flex items-center justify-between gap-3 px-3 py-2">
        <span class="min-w-0 truncate">{{ row.name }} <span class="text-muted-foreground">× {{ row.qty }}</span></span>
        <span class="flex shrink-0 items-center gap-2">
          <span class="font-medium">{{ money(row.amount) }}</span>
          <span class="rounded-full px-2 py-0.5 text-[10px] font-semibold" :class="row.billed ? 'bg-emerald-100 text-emerald-800' : 'bg-amber-100 text-amber-800'">
            {{ row.billed ? $t("medical.money.statePaid") : $t("medical.money.stateUnpaid") }}
          </span>
        </span>
      </li>
    </ul>

    <p v-if="!visit.signedAt" class="text-sm text-muted-foreground">{{ $t("medical.money.notSigned") }}</p>
    <Button v-else-if="unpaid > 0 && canPos" variant="outline" as-child>
      <router-link :to="{ name: 'pos' }"><Wallet class="mr-2 size-4" />{{ $t("medical.money.goPos") }}</router-link>
    </Button>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import { Wallet } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { useAuthStore } from "@/stores";
import type { MedicalVisitDetail } from "@/types/medicalVisit";
import { money } from "../../format";

const props = defineProps<{ visit: MedicalVisitDetail }>();
const { t } = useI18n();
const auth = useAuthStore();
const canPos = computed(() => auth.can("pos", "CREATE"));

// External medicine is free and never billed, so it stays out of this list.
const rows = computed(() =>
  props.visit.items.filter((item) => item.kind !== "external").map((item) => ({ ...item, billed: !!item.invoiceLineId }))
);
const total = computed(() => rows.value.reduce((sum, row) => sum + row.amount, 0));
const paid = computed(() => rows.value.filter((row) => row.billed).reduce((sum, row) => sum + row.amount, 0));
const unpaid = computed(() => total.value - paid.value);

const cards = computed(() => [
  { label: t("medical.money.total"), value: total.value, tone: "" },
  { label: t("medical.money.paid"), value: paid.value, tone: "text-emerald-700" },
  { label: t("medical.money.unpaid"), value: unpaid.value, tone: unpaid.value > 0 ? "text-amber-700" : "" },
]);
</script>
