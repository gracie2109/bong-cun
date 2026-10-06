<template>
  <PageTitle />

  <ContentWrap>
    <div class="container bg-white h-auto w-auto mt-3 min-h-dvh">
      <div class="text-center mx-auto py-6">
        <h1 class="font-bold text-2xl">Setting pet service price</h1>
        <span class="text-center"></span>
      </div>
      <div>
        <ServicePriceTable :isHandleForm="isHandleForm" />
      </div>
    </div>
  </ContentWrap>
</template>

<script setup lang="ts">
import ContentWrap from "@/views/admin/components/ContentWrap.vue";
import PageTitle from "@/views/admin/pets/PageTitle.vue";
import { useRoute } from "vue-router";
import { computed } from "vue";
import ServicePriceTable from "./components/ServicePriceTable.vue";
import { usePetService } from "@/queries/petServices";

const route = useRoute();
const serviceId =
  route.name === "DetailPetService" && route.params.serviceId
    ? String(route.params.serviceId)
    : undefined;
const { data: serviceInfo } = usePetService(serviceId);

const isHandleForm = computed(() =>
  !!serviceInfo.value?.petIds?.includes(String(route.params.petId))
);
</script>
