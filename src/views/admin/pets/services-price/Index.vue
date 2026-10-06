<template>
  <PageTitle />

  <ContentWrap>

    <SubMenu />

    <div class="relative top-20 h-auto overflow-y-auto bg-white w-[93vw]">
      <div class="w-full min-h-dvh space-y-6 ml-2 p-3">
        <div class="service-card grid grid-cols-6 gap-4">
          <div
            class="border border-primary h-[100px] rounded-lg"
            id="create_btn"
          >
            <ModalCreateService :default-pet="petInfo" />
          </div>
          <div
            v-if="!_.isEmpty(petServices) && !loading"
            v-for="(i, j) in petServices.filter((i) =>
              i?.petIds?.includes(petId)
            )"
          >
            <ServiceCard
              :data="i"
              :key="j"
              :enable="String($route.params.petId)"
              :isMouseId="isMouseId"
              @set-mouse-el="handleMouseEv"
            />
          </div>
        </div>
        <div
          class="w-full h-auto overflow-y-auto overflow-x-auto"
          v-if="petServices.length > 0"
        >
          <div class="w-full h-full" id="short_cut_service">
            <ListServicesPriceTable
              :services="petServices.filter((i) => i.petIds.includes(petId))"
              :isMouseId="isMouseId"
              @set-mouse-el="handleMouseEv"
            />
          </div>
        </div>
      </div>
    </div>
  </ContentWrap>
</template>

<script setup lang="ts">
import { useAllPetServices } from "@/queries/petServices";
import { usePet } from "@/queries/pets";
import { ContentWrap } from "@/views/admin/components";
import PageTitle from "../PageTitle.vue";
import { computed, ref } from "vue";
import ServiceCard from "../services/components/ServiceCard.vue";
import ListServicesPriceTable from "./components/ListServicesPriceTable.vue";
import ModalCreateService from "../components/ModalCreateService.vue";
import SubMenu from "../components/SubMenu.vue";
import { useRoute } from "vue-router";
import _ from "lodash"

const { params } = useRoute();
const petId = String(params.petId);
const servicesQuery = useAllPetServices();
const petServices = computed(() => servicesQuery.data.value ?? []);
const loading = servicesQuery.isPending;

const { data: pet } = usePet(petId);
// ModalCreateService pre-selects the current pet from a list.
const petInfo = computed(() => (pet.value ? [pet.value] : undefined));

const isMouseId = ref("");
const handleMouseEv = (value: string) => {
  isMouseId.value = value;
};
</script>
