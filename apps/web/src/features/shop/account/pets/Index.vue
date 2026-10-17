<template>
  <section class="max-w-4xl space-y-4 pb-12">
    <div>
      <h2 class="text-lg font-semibold">{{ $t("client.pets.title") }}</h2>
      <p class="text-sm text-muted-foreground">{{ $t("client.pets.intro") }}</p>
    </div>

    <p v-if="page.loading.value" class="py-8 text-center text-muted-foreground">{{ $t("petCare.common.loading") }}</p>
    <div v-else-if="page.failed.value" class="py-12 text-center">
      <p class="mb-3 text-muted-foreground">{{ $t("client.pets.loadFailed") }}</p>
      <Button variant="outline" @click="page.retry">{{ $t("client.catalog.retry") }}</Button>
    </div>
    <div v-else-if="!page.hasCustomer.value" class="rounded-xl border border-dashed py-12 text-center">
      <p class="mb-3 text-muted-foreground">{{ $t("client.pets.needProfile") }}</p>
      <Button as-child variant="outline">
        <RouterLink :to="{ name: 'account-profile' }">{{ $t("client.pets.goProfile") }}</RouterLink>
      </Button>
    </div>
    <div v-else-if="page.pets.value.length === 0" class="rounded-xl border border-dashed py-12 text-center text-muted-foreground">
      {{ $t("client.pets.empty") }}
    </div>
    <div v-else class="grid gap-3 sm:grid-cols-2">
      <PetCard v-for="pet in page.pets.value" :key="pet.id" :pet="pet" />
    </div>
  </section>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import { useMyPets } from "@/features/shop/account/composables/useMyPets";
import PetCard from "./components/PetCard.vue";

const page = useMyPets();
</script>
