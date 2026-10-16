<template>
  <div class="mx-auto w-full max-w-3xl space-y-5 pb-10">
    <Button as-child variant="ghost" size="sm" class="-ml-2">
      <RouterLink :to="{ name: 'account-boarding' }"><ArrowLeft class="mr-1 size-4" />{{ $t("client.boarding.back") }}</RouterLink>
    </Button>

    <p v-if="query.isLoading.value" class="py-12 text-center text-muted-foreground">{{ $t("petCare.common.loading") }}</p>
    <div v-else-if="query.isError.value || !stay" class="py-12 text-center">
      <p class="mb-3 text-muted-foreground">{{ $t("client.boarding.loadFailed") }}</p>
      <Button variant="outline" @click="query.refetch()">{{ $t("client.catalog.retry") }}</Button>
    </div>
    <template v-else>
      <section class="space-y-2 rounded-xl border bg-white p-4">
        <div class="flex flex-wrap items-start justify-between gap-2">
          <div>
            <p class="font-mono text-sm font-semibold">{{ stay.code }}</p>
            <p class="font-semibold">{{ dayLabel(dayOf(stay.plannedInAt), locale) }}</p>
            <p class="text-sm text-primary">{{ $t("client.boarding.until", { day: dayLabel(dayOf(stay.plannedOutAt), locale) }) }}</p>
          </div>
          <span class="rounded-full px-2.5 py-0.5 text-xs font-semibold" :class="STATUS_TONE[stay.status] ?? 'bg-muted text-muted-foreground'">
            {{ $t(`client.boarding.status.${stay.status}`) }}
          </span>
        </div>
        <p class="text-sm text-muted-foreground">
          {{ stay.branchName }}
          <a v-if="stay.branchPhone" :href="`tel:${stay.branchPhone}`" class="font-medium text-primary"> · {{ stay.branchPhone }}</a>
        </p>
      </section>

      <section class="space-y-2">
        <h2 class="text-sm font-semibold">{{ $t("client.boarding.pets") }}</h2>
        <ul class="space-y-2">
          <li v-for="(pet, index) in stay.pets" :key="index" class="rounded-lg border bg-white px-3 py-2 text-sm">
            <p class="flex items-center gap-2">
              <PetAvatar :name="pet.petName" :photo-url="pet.petPhotoUrl" class="size-7 text-[10px]" />
              <span><span class="font-medium">{{ pet.petName }}</span> · {{ pet.kennelTypeName }} · {{ $t("client.boarding.nights", { n: pet.chargedNights }) }}</span>
            </p>
            <p v-if="pet.feeding" class="text-muted-foreground">{{ $t("client.boarding.feeding") }}: {{ pet.feeding }}</p>
            <p v-if="pet.medication" class="text-muted-foreground">{{ $t("client.boarding.medication") }}: {{ pet.medication }}</p>
          </li>
        </ul>
      </section>

      <section class="space-y-2">
        <h2 class="text-sm font-semibold">{{ $t("client.boarding.careLog") }}</h2>
        <CareTimeline :logs="stay.careLogs" />
      </section>

      <section class="space-y-2">
        <h2 class="text-sm font-semibold">{{ stay.isFinal ? $t("client.boarding.total") : $t("client.boarding.estimate") }}</h2>
        <ul v-if="stay.charges.length" class="divide-y rounded-lg border bg-white text-sm">
          <li v-for="charge in stay.charges" :key="charge.id" class="flex items-start justify-between gap-3 px-3 py-2">
            <span>{{ charge.name }}<span v-if="charge.qty !== 1" class="text-muted-foreground"> × {{ charge.qty }}</span></span>
            <span class="shrink-0">{{ formatPrice(charge.amount) }}</span>
          </li>
        </ul>
        <p class="text-right text-sm">
          <span class="font-semibold text-primary">{{ formatPrice(stay.estTotal) }}</span>
        </p>
        <p v-if="!stay.isFinal" class="text-xs text-muted-foreground">{{ $t("client.boarding.estimateNote") }}</p>
      </section>
    </template>
  </div>
</template>

<script lang="ts" setup>
import PetAvatar from "@/components/common/PetAvatar.vue";
import { computed } from "vue";
import { useRoute } from "vue-router";
import { useI18n } from "vue-i18n";
import { ArrowLeft } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { formatPrice } from "@/lib/utils";
import { useMyBoardingStay } from "@/queries/accountBoarding";
import { dayLabel } from "@bongcun/core/spa";
import CareTimeline from "./components/CareTimeline.vue";
import { dayOf, STATUS_TONE } from "./format";

const { locale } = useI18n();
const route = useRoute();
const query = useMyBoardingStay(computed(() => String(route.params.id ?? "")));
const stay = computed(() => query.data.value ?? null);
</script>
