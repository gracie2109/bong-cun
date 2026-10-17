<template>
  <div class="space-y-4">
    <section class="rounded-xl bg-[#fff8f0] p-6">
      <h2 class="text-xl font-bold">{{ $t("client.account.overview.hello", { name: displayName }) }}</h2>
      <p class="mt-1 text-sm text-muted-foreground">{{ $t("client.account.overview.intro") }}</p>
    </section>
    <div class="grid gap-3 sm:grid-cols-2">
      <NextAppointmentTile :appointment="nextAppointment" />
      <PetsTile :count="petCount" />
      <CurrentStayTile v-if="currentStay" :stay="currentStay" />
    </div>
    <RecentOrders :orders="orders.slice(0, RECENT_ORDERS)" :loading="loading" />
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { storeToRefs } from "pinia";
import { useMyPets, useMyProfile } from "@/queries/account";
import { useMyAppointments } from "@/queries/accountAppointments";
import { useMyBoardingStays } from "@/queries/accountBoarding";
import { useMyShopOrders } from "@/queries/shopOrders";
import { useAuthStore } from "@/stores";
import CurrentStayTile from "./components/CurrentStayTile.vue";
import NextAppointmentTile from "./components/NextAppointmentTile.vue";
import PetsTile from "./components/PetsTile.vue";
import RecentOrders from "./components/RecentOrders.vue";

const RECENT_ORDERS = 3;

const { currentUser } = storeToRefs(useAuthStore());
const profile = useMyProfile();
const hasCustomer = computed(() => Boolean(profile.data.value?.customerId));
const petsQuery = useMyPets(hasCustomer);
const appointmentsQuery = useMyAppointments("upcoming", 1, 1, hasCustomer);
const boardingQuery = useMyBoardingStays("current", 1, 1, hasCustomer);
const ordersQuery = useMyShopOrders(null, 1, RECENT_ORDERS);

const displayName = computed(() => profile.data.value?.fullName || currentUser.value?.displayName || currentUser.value?.email || "");
const orders = computed(() => ordersQuery.data.value?.rows ?? []);
const nextAppointment = computed(() => appointmentsQuery.data.value?.rows[0] ?? null);
// The tile only shows while a pet is in the hotel.
const currentStay = computed(() => boardingQuery.data.value?.rows[0] ?? null);
const petCount = computed(() => (hasCustomer.value && petsQuery.data.value ? petsQuery.data.value.filter((pet) => pet.status === "active").length : null));
const loading = computed(() => ordersQuery.isLoading.value);
</script>
