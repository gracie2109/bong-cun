<template>
  <div class="pb-16">
    <BoardingHero :phone="phone" />

    <div class="shop-container pt-10 md:pt-14">
      <!-- Client only, like the spa price list: the page needs the branch first. -->
      <ClientOnly>
        <SpaCatalogSkeleton v-if="query.isLoading.value" />
        <EmptyState v-else-if="query.isError.value" tone="error" :title="$t('client.boarding.loadFailed')" :text="$t('client.catalog.errorHint')">
          <Button class="h-11 rounded-full px-6" @click="query.refetch()">{{ $t("client.catalog.retry") }}</Button>
        </EmptyState>
        <EmptyState v-else-if="!catalog || !catalog.kennelTypes.length" :title="$t('client.boarding.emptyPublic')" :text="$t('client.boarding.emptyHint')">
          <Button as-child variant="outline" class="h-11 rounded-full px-6">
            <a :href="`tel:${STORE_INFO.phone}`">{{ STORE_INFO.phone }}</a>
          </Button>
        </EmptyState>
        <template v-else>
          <h2 class="text-2xl font-extrabold tracking-tight">{{ $t("client.boarding.priceTitle") }}</h2>
          <ul class="mt-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <li v-for="type in catalog.kennelTypes" :key="type.id"><KennelTypeCard :type="type" /></li>
          </ul>

          <section v-if="catalog.rules" class="mt-10 rounded-[32px] bg-white p-6 ring-1 ring-border/70 md:p-8" aria-labelledby="boarding-rules">
            <h2 id="boarding-rules" class="shop-display text-2xl">{{ $t("client.boarding.rulesTitle") }}</h2>
            <ul class="mt-4 space-y-2 text-muted-foreground">
              <li>{{ $t("client.boarding.ruleCheckIn", { time: catalog.rules.checkInFrom }) }}</li>
              <li>{{ $t("client.boarding.ruleCheckOut", { time: catalog.rules.checkOutBy }) }}</li>
              <li>{{ $t("client.boarding.ruleLate", { half: catalog.rules.checkOutBy, full: catalog.rules.lateHalfUntil }) }}</li>
              <li>{{ $t("client.boarding.ruleVaccine") }}</li>
            </ul>
          </section>

          <p class="mt-6 flex gap-2 text-sm text-muted-foreground">
            <Info class="mt-0.5 size-4 shrink-0" aria-hidden="true" />{{ $t("client.boarding.priceNote") }}
          </p>
        </template>
        <template #fallback><SpaCatalogSkeleton /></template>
      </ClientOnly>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Info } from "lucide-vue-next";
import EmptyState from "@/components/shop/EmptyState.vue";
import { Button } from "@/components/ui/button";
import { STORE_INFO } from "@/config/storeInfo";
import { useBoardingPublicCatalog } from "@/features/shop/boarding/queries/boardingWeb";
import { SpaCatalogSkeleton } from "@/features/shop/spa";
import BoardingHero from "./components/BoardingHero.vue";
import KennelTypeCard from "./components/KennelTypeCard.vue";

const query = useBoardingPublicCatalog();
const catalog = computed(() => query.data.value ?? null);
// The branch phone when it has one, else the shop's.
const phone = computed(() => catalog.value?.branch?.phone || STORE_INFO.phone);
</script>
