<template>
  <section class="space-y-4 rounded-xl border bg-white p-4">
    <div>
      <h2 class="mb-2 text-sm font-semibold">{{ $t("reports.mix.segments") }}</h2>
      <MixRow :label="$t('reports.segment.shop')" :value="shopNet" :total="segmentTotal" color="#0F766E" />
      <MixRow :label="$t('reports.segment.spa')" :value="data.segments.spa" :total="segmentTotal" color="#F59E0B" />
      <MixRow :label="$t('reports.mix.spaAppointment')" :value="data.segments.spaAppointment" :total="segmentTotal" sub />
      <MixRow :label="$t('reports.mix.spaWalkIn')" :value="data.segments.spaWalkIn" :total="segmentTotal" sub />
      <MixRow :label="$t('reports.segment.boarding')" :value="data.segments.boarding" :total="segmentTotal" color="#6366F1" />
      <MixRow :label="$t('reports.segment.medical')" :value="data.segments.medical" :total="segmentTotal" color="#E11D48" />
      <p class="mt-1 text-[11px] text-muted-foreground">{{ $t("reports.mix.discountNote") }}</p>
    </div>
    <div>
      <h2 class="mb-2 text-sm font-semibold">{{ $t("reports.mix.payments") }}</h2>
      <MixRow :label="$t('reports.method.cash')" :value="data.payments.cash" :total="paymentTotal" />
      <MixRow :label="$t('reports.method.transfer')" :value="data.payments.transfer" :total="paymentTotal" />
      <MixRow :label="$t('reports.method.card')" :value="data.payments.card" :total="paymentTotal" />
      <MixRow v-if="data.payments.cod > 0" :label="$t('reports.method.cod')" :value="data.payments.cod" :total="paymentTotal" />
    </div>
  </section>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import type { ReportOverview } from "@/repositories/reports";
import MixRow from "./MixRow.vue";

const props = defineProps<{ data: ReportOverview }>();

// Refunds are all goods, so the Shop share is shown after them.
const shopNet = computed(() => props.data.segments.shop - props.data.refunds);
const segmentTotal = computed(() => shopNet.value + props.data.segments.spa + props.data.segments.boarding + props.data.segments.medical);
const paymentTotal = computed(
  () => props.data.payments.cash + props.data.payments.transfer + props.data.payments.card + props.data.payments.cod
);
</script>
