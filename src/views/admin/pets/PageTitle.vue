<template>
  <Header>
    <div class="flex gap-x-2 items-center">
      <h1
        class="font-semibold flex items-center gap-2"
        :class="
          clsx({
            'cursor-pointer': !isShowAllPets,
          })
        "
        @click="
          () => {
            if (isShowAllPets) return;
            else $router.push({ name: 'pets' });
          }
        "
      >
        <PawPrint class="size-4 text-primary" />
        {{ $t("pageMeta.pets") }} ({{ petRecords }})
      </h1>

      <div v-if="$route.name !== 'pets'" class="flex">
        <div
          id="services"
          class="flex items-center cursor-pointer"
          @click="handleBackService"
        >
          <ChevronRight class="size-4 mr-2" />
          <h1
            class="font-semibold flex items-center gap-2 text-muted-foreground"
          >
            {{ $t("pageMeta.settingPetServicePrice") }}
          </h1>
        </div>

        <div
          class="flex items-center cursor-pointer"
          v-if="petInfo || petId"
          @click="handleBackPet"
        >
          <ChevronRight class="size-4 mr-2" />
          <div class="flex items-center h-full gap-2">
            <Icon :icon="petInfo.icon ?? ''" v-if="petInfo"/>
            <h1
              class="font-semibold flex items-center gap-2 text-muted-foreground"
            >
              {{ petInfo?.name || petId}}
            </h1>
          </div>
        </div>
        <div class="flex items-center cursor-pointer" v-if="serviceInfo">
          <ChevronRight class="size-4 mr-2" />
          <div class="flex items-center h-full gap-2">
            <h1
              class="font-semibold flex items-center gap-2 text-muted-foreground"
            >
              {{ serviceInfo.name }}
            </h1>
          </div>
        </div>
      </div>
    </div>
  </Header>
</template>

<script setup lang="ts">
import { usePet, usePetsList } from "@/queries/pets";
import { usePetService } from "@/queries/petServices";

import { Header } from "@/views/admin/components";
import clsx from "clsx";
import { PawPrint, ChevronRight } from "lucide-vue-next";
import { computed } from "vue";
import { useRoute, useRouter } from "vue-router";
import { Icon } from "@iconify/vue";

const route = useRoute();
const router = useRouter();
const { petId, serviceId } = route.params;

// Only the total is needed here, so ask for a single row.
const { data: petPage } = usePetsList({ pageIndex: 1, pageSize: 1 });
const petRecords = computed(() => petPage.value?.total ?? 0);

const { data: petInfo } = usePet(petId ? String(petId) : undefined);
const { data: serviceInfo } = usePetService(serviceId ? String(serviceId) : undefined);

const isShowAllPets = computed(() => {
  if (route.name === "pets") return true;
  else return false;
});

function handleBackPet() {
  router.push({
    name: "settingPetServicePrice",
    params: { petId: petId },
  });
}
function handleBackService() {
  router.push({
    name: "petService",
  });
}
</script>
