<template>
  <div class="mx-auto w-full max-w-3xl space-y-5 pb-10">
    <Button as-child variant="ghost" size="sm" class="-ml-2">
      <RouterLink :to="{ name: 'account-pets' }"><ArrowLeft class="mr-1 size-4" />{{ $t("client.health.back") }}</RouterLink>
    </Button>

    <p v-if="query.isLoading.value" class="py-12 text-center text-muted-foreground">{{ $t("petCare.common.loading") }}</p>
    <div v-else-if="query.isError.value || !health" class="py-12 text-center">
      <p class="mb-3 text-muted-foreground">{{ $t("client.health.loadFailed") }}</p>
      <Button variant="outline" @click="query.refetch()">{{ $t("client.catalog.retry") }}</Button>
    </div>
    <template v-else>
      <div class="flex items-center gap-3">
        <PetAvatar :name="health.petName" :photo-url="health.petPhotoUrl" class="size-14 text-base" />
        <div>
          <h2 class="text-lg font-semibold">{{ $t("client.health.title", { name: health.petName }) }}</h2>
          <p v-if="health.status === 'deceased'" class="text-sm font-medium text-muted-foreground">
            {{ health.deceasedOn ? $t("client.pets.deceasedOn", { date: formatDay(health.deceasedOn) }) : $t("client.pets.deceased") }}
          </p>
          <p class="text-sm text-muted-foreground">{{ $t("client.health.intro") }}</p>
        </div>
      </div>

      <Tabs default-value="vaccines">
        <TabsList>
          <TabsTrigger value="vaccines">{{ $t("client.health.tabVaccines") }}</TabsTrigger>
          <TabsTrigger value="visits">{{ $t("client.health.tabVisits") }} ({{ health.visits.length }})</TabsTrigger>
        </TabsList>
        <TabsContent value="vaccines" class="pt-4"><VaccineBook :vaccines="health.vaccines" /></TabsContent>
        <TabsContent value="visits" class="pt-4"><VisitHistory :visits="health.visits" /></TabsContent>
      </Tabs>

      <p class="rounded-xl border border-dashed bg-white p-3 text-sm text-muted-foreground">
        {{ $t("client.health.book") }}
        <a v-if="health.phone" :href="`tel:${health.phone}`" class="font-medium text-primary">{{ health.phone }}</a>
      </p>
    </template>
  </div>
</template>

<script lang="ts" setup>
import PetAvatar from "@/components/common/PetAvatar.vue";
import { computed } from "vue";
import { useRoute } from "vue-router";
import { ArrowLeft } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { useMyPetHealth } from "@/features/shop/account/queries/accountHealth";
import { formatDay } from "./format";
import VaccineBook from "./VaccineBook.vue";
import VisitHistory from "./VisitHistory.vue";

const route = useRoute();
const query = useMyPetHealth(computed(() => String(route.params.id ?? "")));
const health = computed(() => query.data.value ?? null);
</script>
