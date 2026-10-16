<template>
  <div class="pb-16">
    <SpaHero :book-target="bookTarget" :book-label="bookLabel" />

    <div class="shop-container pt-10 md:pt-14">
      <!-- Client only: the price list needs the branch first, which the server render cannot wait for. -->
      <ClientOnly>
        <div v-if="catalog.branches.value.length > 1" class="mb-6">
          <PillGroup
            :options="catalog.branches.value"
            :model-value="catalog.branchId.value"
            :label="$t('client.spa.branch')"
            @update:model-value="catalog.pickBranch"
          />
        </div>

        <SpaCatalogSkeleton v-if="catalog.loading.value" />
        <EmptyState
          v-else-if="catalog.failed.value"
          tone="error"
          :title="$t('client.spa.loadFailed')"
          :text="$t('client.catalog.errorHint')"
        >
          <Button class="h-11 rounded-full px-6" @click="catalog.retry">{{ $t("client.catalog.retry") }}</Button>
        </EmptyState>
        <EmptyState v-else-if="!catalog.species.value" :title="$t('client.spa.empty')" :text="$t('client.spa.emptyHint')">
          <Button as-child variant="outline" class="h-11 rounded-full px-6">
            <a :href="`tel:${STORE_INFO.phone}`">{{ STORE_INFO.phone }}</a>
          </Button>
        </EmptyState>
        <template v-else>
          <div class="flex flex-wrap items-center justify-between gap-4">
            <h2 class="text-2xl font-extrabold tracking-tight">
              {{ $t("client.spa.priceTitle") }}
            </h2>
            <PillGroup
              :options="catalog.speciesList.value"
              :model-value="catalog.species.value.id"
              :label="$t('client.spa.species')"
              @update:model-value="catalog.pickSpecies"
            />
          </div>

          <section v-if="catalog.combos.value.length" class="mt-8" aria-labelledby="spa-combos">
            <h3 id="spa-combos" class="shop-eyebrow !text-sage">
              {{ $t("client.spa.combos") }}
            </h3>
            <ComboList class="mt-4" :combos="catalog.combos.value" />
          </section>

          <section v-if="catalog.services.value.length" class="mt-10" aria-labelledby="spa-services">
            <h3 id="spa-services" class="shop-eyebrow !text-sage">
              {{ $t("client.spa.services") }}
            </h3>
            <ServicePriceList class="mt-4" :services="catalog.services.value" :species="catalog.species.value" />
          </section>

          <p class="mt-6 flex gap-2 text-sm text-muted-foreground">
            <Info class="mt-0.5 size-4 shrink-0" aria-hidden="true" />{{ $t("client.spa.priceNote") }}
          </p>
        </template>
        <template #fallback><SpaCatalogSkeleton /></template>
      </ClientOnly>

      <section class="mt-16 rounded-[32px] bg-white p-6 ring-1 ring-border/70 md:p-10" aria-labelledby="spa-how">
        <div class="flex flex-wrap items-end justify-between gap-4">
          <h2 id="spa-how" class="shop-display text-2xl md:text-3xl">
            {{ $t("client.spa.howTitle") }}
          </h2>
          <Button as-child class="h-12 rounded-full bg-sage px-6 text-base hover:bg-sage/90">
            <RouterLink :to="bookTarget"><CalendarPlus class="mr-2 size-5" />{{ bookLabel }}</RouterLink>
          </Button>
        </div>
        <BookingHowTo class="mt-8" />
      </section>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { storeToRefs } from "pinia";
import { useI18n } from "vue-i18n";
import { CalendarPlus, Info } from "lucide-vue-next";
import EmptyState from "@/components/shop/EmptyState.vue";
import PillGroup from "@/components/shop/PillGroup.vue";
import BookingHowTo from "@/components/shop/spa/BookingHowTo.vue";
import { Button } from "@/components/ui/button";
import { useSpaCatalog } from "@/composables/spa/useSpaCatalog";
import { STORE_INFO } from "@/config/storeInfo";
import { useAuthStore } from "@/stores";
import ComboList from "./components/ComboList.vue";
import ServicePriceList from "./components/ServicePriceList.vue";
import SpaCatalogSkeleton from "./components/SpaCatalogSkeleton.vue";
import SpaHero from "./components/SpaHero.vue";

const { t } = useI18n();
const catalog = useSpaCatalog();
const { currentUser } = storeToRefs(useAuthStore());
const signedIn = computed(() => Boolean(currentUser.value));
// The booking wizard (next step) needs a signed-in customer; guests are sent to sign in first.
const bookTarget = computed(() => (signedIn.value ? { path: "/spa/book" } : { name: "login", query: { redirect: "/spa/book" } }));
const bookLabel = computed(() => (signedIn.value ? t("client.spa.book") : t("client.spa.signInToBook")));
</script>
