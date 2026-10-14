<template>
  <section class="mx-auto max-w-5xl space-y-6 px-4 pb-16 pt-6">
    <header class="flex flex-wrap items-end justify-between gap-3">
      <div>
        <h1 class="text-2xl font-bold">{{ $t("client.spa.title") }}</h1>
        <p class="mt-1 text-sm text-muted-foreground">{{ $t("client.spa.intro") }}</p>
      </div>
      <Button as-child>
        <RouterLink :to="bookTarget">
          <CalendarPlus class="mr-1 size-4" />
          {{ signedIn ? $t("client.spa.book") : $t("client.spa.signInToBook") }}
        </RouterLink>
      </Button>
    </header>

    <div v-if="catalog.branches.value.length > 1" class="flex flex-wrap gap-2">
      <Button
        v-for="branch in catalog.branches.value"
        :key="branch.id"
        size="sm"
        :variant="branch.id === catalog.branchId.value ? 'default' : 'outline'"
        @click="catalog.pickBranch(branch.id)"
      >
        {{ branch.name }}
      </Button>
    </div>

    <p v-if="catalog.loading.value" class="py-12 text-center text-muted-foreground">{{ $t("petCare.common.loading") }}</p>
    <div v-else-if="catalog.failed.value" class="py-12 text-center">
      <p class="mb-3 text-muted-foreground">{{ $t("client.spa.loadFailed") }}</p>
      <Button variant="outline" @click="catalog.retry">{{ $t("client.catalog.retry") }}</Button>
    </div>
    <div v-else-if="!catalog.species.value" class="rounded-xl border border-dashed py-12 text-center text-muted-foreground">
      {{ $t("client.spa.empty") }}
    </div>
    <template v-else>
      <div class="flex flex-wrap gap-2" role="tablist">
        <Button
          v-for="item in catalog.speciesList.value"
          :key="item.id"
          size="sm"
          role="tab"
          :aria-selected="item.id === catalog.species.value.id"
          :variant="item.id === catalog.species.value.id ? 'default' : 'outline'"
          @click="catalog.pickSpecies(item.id)"
        >
          {{ item.name }}
        </Button>
      </div>

      <div v-if="catalog.combos.value.length" class="space-y-3">
        <h2 class="text-lg font-semibold">{{ $t("client.spa.combos") }}</h2>
        <ComboList :combos="catalog.combos.value" />
      </div>

      <div v-if="catalog.services.value.length" class="space-y-3">
        <h2 class="text-lg font-semibold">{{ $t("client.spa.services") }}</h2>
        <ServicePriceList :services="catalog.services.value" :species="catalog.species.value" />
      </div>

      <p class="text-xs text-muted-foreground">{{ $t("client.spa.priceNote") }}</p>
    </template>
  </section>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { storeToRefs } from "pinia";
import { CalendarPlus } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { useSpaCatalog } from "@/composables/spa/useSpaCatalog";
import { useAuthStore } from "@/stores";
import ComboList from "./components/ComboList.vue";
import ServicePriceList from "./components/ServicePriceList.vue";

const catalog = useSpaCatalog();
const { currentUser } = storeToRefs(useAuthStore());
const signedIn = computed(() => Boolean(currentUser.value));
// The booking wizard (next step) needs a signed-in customer; guests are sent to sign in first.
const bookTarget = computed(() => (signedIn.value ? { path: "/spa/book" } : { name: "login", query: { redirect: "/spa/book" } }));
</script>
