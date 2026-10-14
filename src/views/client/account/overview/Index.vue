<template>
  <div class="space-y-4">
    <section class="rounded-xl bg-[#fff8f0] p-6">
      <h2 class="text-xl font-bold">{{ $t("client.account.overview.hello", { name: displayName }) }}</h2>
      <p class="mt-1 text-sm text-muted-foreground">{{ $t("client.account.overview.intro") }}</p>
    </section>
    <RecentOrders :orders="orders.slice(0, RECENT_ORDERS)" :loading="loading" />
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { storeToRefs } from "pinia";
import { useMyProfile } from "@/queries/account";
import { useMyShopOrders } from "@/queries/shopOrders";
import { useAuthStore } from "@/stores";
import RecentOrders from "./components/RecentOrders.vue";

const RECENT_ORDERS = 3;

const { currentUser } = storeToRefs(useAuthStore());
const profile = useMyProfile();
const ordersQuery = useMyShopOrders(null, 1, RECENT_ORDERS);

const displayName = computed(() => profile.data.value?.fullName || currentUser.value?.displayName || currentUser.value?.email || "");
const orders = computed(() => ordersQuery.data.value?.rows ?? []);
const loading = computed(() => ordersQuery.isLoading.value);
</script>
