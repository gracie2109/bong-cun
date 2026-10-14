<template>
  <footer class="bg-[#1e2121] px-4 py-10 text-sm text-gray-400">
    <div class="container grid gap-8 md:grid-cols-3">
      <div class="space-y-4">
        <div class="w-[150px]"><AppLogo /></div>
        <p>{{ $t("client.footer.tagline") }}</p>
      </div>

      <div class="space-y-3">
        <h3 class="font-semibold text-white">{{ $t("client.footer.links") }}</h3>
        <ul class="space-y-2">
          <li v-for="link in navigation.clientNav" :key="link.name">
            <RouterLink :to="{ name: link.name }" class="hover:text-primary" @click="scrollToTop">
              {{ $t(link.title) }}
            </RouterLink>
          </li>
        </ul>
      </div>

      <div class="space-y-3">
        <h3 class="font-semibold text-white">{{ $t("client.footer.contact") }}</h3>
        <StoreContactList />
      </div>
    </div>
    <p class="container mt-8 border-t border-white/10 pt-4 text-xs">
      © {{ year }} {{ STORE_INFO.name }}. {{ $t("client.footer.rights") }}
    </p>
  </footer>
</template>

<script setup lang="ts">
import AppLogo from "@/components/common/AppLogo.vue";
import { STORE_INFO } from "@/config/storeInfo";
import { navigation } from "@/lib/navigations";
import StoreContactList from "./StoreContactList.vue";

const year = new Date().getFullYear();
const scrollToTop = () => window.scrollTo({ top: 0, behavior: "smooth" });
</script>
