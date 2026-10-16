<template>
  <article id="medical-prescription-sheet" class="space-y-4 bg-white p-6 text-sm text-black">
    <header class="border-b pb-3 text-center">
      <p class="text-base font-bold uppercase">{{ rx.branchName }}</p>
      <h2 class="text-lg font-bold">{{ $t("medical.rx.title") }}</h2>
      <p class="text-xs">{{ rx.code }} · {{ rx.date }}</p>
    </header>

    <section class="grid grid-cols-2 gap-2">
      <p><span class="font-semibold">{{ $t("medical.rx.pet") }}:</span> {{ rx.petName }}<template v-if="rx.speciesName"> ({{ rx.speciesName }})</template></p>
      <p v-if="rx.weightKg"><span class="font-semibold">{{ $t("medical.vitals.weight") }}:</span> {{ rx.weightKg }} kg</p>
      <p><span class="font-semibold">{{ $t("medical.rx.owner") }}:</span> {{ rx.customerName }}</p>
      <p><span class="font-semibold">{{ $t("medical.rx.phone") }}:</span> {{ rx.customerPhone }}</p>
    </section>

    <p v-if="rx.diagnoses.length"><span class="font-semibold">{{ $t("medical.record.diagnoses") }}:</span> {{ rx.diagnoses.join(", ") }}</p>

    <ol class="list-decimal space-y-2 pl-5">
      <li v-for="(line, index) in rx.items" :key="index">
        <p class="font-semibold">
          {{ line.name }} <span class="font-normal">· {{ line.qty }}<template v-if="line.unitName"> {{ line.unitName }}</template></span>
          <span v-if="line.external" class="ml-1 text-xs font-normal italic">({{ $t("medical.rx.external") }})</span>
        </p>
        <p class="text-xs">
          {{ [line.dose, line.frequency, line.days ? `${line.days} ${$t("medical.items.daysUnit")}` : null, line.route, line.instructions].filter(Boolean).join(" · ") }}
        </p>
      </li>
    </ol>

    <p v-if="rx.ownerInstructions"><span class="font-semibold">{{ $t("medical.record.instructions") }}:</span> {{ rx.ownerInstructions }}</p>
    <p v-if="rx.recheckOn"><span class="font-semibold">{{ $t("medical.record.recheckOn") }}:</span> {{ rx.recheckOn }}</p>

    <footer class="pt-6 text-right">
      <p class="font-semibold">{{ $t("medical.rx.vet") }}</p>
      <p class="mt-8">{{ rx.vetName }}</p>
    </footer>
  </article>
</template>

<script lang="ts" setup>
import type { Prescription } from "@bongcun/core/medical";

defineProps<{ rx: Prescription }>();
</script>

<style>
/* Printing shows the prescription alone, whatever the page around it. */
@media print {
  body * {
    visibility: hidden;
  }
  #medical-prescription-sheet,
  #medical-prescription-sheet * {
    visibility: visible;
  }
  #medical-prescription-sheet {
    position: fixed;
    inset: 0;
  }
}
</style>
