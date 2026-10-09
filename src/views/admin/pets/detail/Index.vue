<template>
  <Header>
    <h1 class="font-semibold flex items-center gap-2">
      <router-link :to="{ name: 'pets' }" class="flex items-center gap-2 text-muted-foreground hover:text-primary">
        <PawPrint class="size-4 text-primary" />
        {{ $t("petCare.pets.title") }}
      </router-link>
      <ChevronRight class="size-4 text-muted-foreground" />
      <span>{{ pet?.name ?? "" }}</span>
    </h1>
  </Header>

  <ContentWrap>
    <div class="space-y-5">
      <PetsNav />

      <div v-if="petQuery.isPending.value" class="space-y-4">
        <Skeleton class="h-40 w-full" />
        <Skeleton class="h-64 w-full" />
      </div>

      <div v-else-if="!pet" class="rounded-xl border bg-white p-10 text-center text-muted-foreground">
        {{ $t("petCare.pets.detail.notFound") }}
      </div>

      <template v-else>
        <PetProfileHeader
          :pet="pet"
          :can-update="canUpdate"
          :latest-weight-kg="pet.weights[0]?.weightKg"
          @edit="editOpen = true"
          @change-status="changeStatus"
        />

        <div class="grid gap-5 xl:grid-cols-[24rem_minmax(0,1fr)]">
          <div class="space-y-5">
            <PetOwnersCard :owners="pet.owners" />
            <PetWeightCard
              :pet-id="petId"
              :species-id="pet.speciesId"
              :weights="pet.weights"
              :can-update="canUpdate"
            />
          </div>

          <PetActivityTabs />
        </div>


        <PetEditSheet v-model:open="editOpen" :pet="pet" />
      </template>
    </div>
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { useRoute } from "vue-router";
import { ChevronRight, PawPrint } from "lucide-vue-next";
import { Skeleton } from "@/components/ui/skeleton";
import { usePermission } from "@/composables/usePermission";
import { usePet, useSetPetStatus } from "@/queries/pets";
import type { PetStatus } from "@/repositories/pets";
import { ContentWrap, Header } from "@/views/admin/components";
import PetEditSheet from "../components/PetEditSheet.vue";
import PetsNav from "../PetsNav.vue";
import PetActivityTabs from "./PetActivityTabs.vue";
import PetOwnersCard from "./PetOwnersCard.vue";
import PetProfileHeader from "./PetProfileHeader.vue";
import PetWeightCard from "./PetWeightCard.vue";

const route = useRoute();
const { canUpdate } = usePermission("pets");
const petId = computed(() => String(route.params.petId));

const petQuery = usePet(petId);
const pet = computed(() => petQuery.data.value ?? null);

const editOpen = ref(false);
const setStatus = useSetPetStatus();

const changeStatus = async (status: PetStatus) => {
  try {
    await setStatus.mutateAsync({ id: petId.value, status });
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
