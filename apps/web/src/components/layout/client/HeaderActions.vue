<template>
  <div class="flex items-center gap-1 sm:gap-2">
    <LangToggle class="hidden lg:inline-flex" />
    <div v-if="user" class="grid size-11 place-content-center"><AccountMenu /></div>
    <button
      v-else
      type="button"
      class="hidden h-11 items-center gap-2 whitespace-nowrap rounded-full px-3 text-sm font-medium transition-colors hover:bg-muted sm:inline-flex"
      @click="loginOpen = true"
    >
      <UserRound class="size-5" :stroke-width="1.8" />{{ $t("client.menu.login") }}
    </button>
    <button
      v-if="!user"
      type="button"
      class="grid size-11 place-content-center rounded-full transition-colors hover:bg-muted sm:hidden"
      :aria-label="$t('client.menu.login')"
      @click="loginOpen = true"
    >
      <UserRound class="size-[22px]" :stroke-width="1.8" />
    </button>
    <CartMenu />
    <Button as-child class="ml-1 hidden h-11 rounded-full px-5 2xl:inline-flex">
      <RouterLink :to="{ name: 'spa' }"><CalendarHeart class="mr-2 size-4" />{{ $t("client.header.bookSpa") }}</RouterLink>
    </Button>
  </div>
  <LoginDialog v-model:open="loginOpen" />
</template>

<script lang="ts" setup>
import { ref } from "vue";
import { storeToRefs } from "pinia";
import { CalendarHeart, UserRound } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { useAuthStore } from "@/stores";
import AccountMenu from "@/views/client/layout/AccountMenu.vue";
import CartMenu from "./CartMenu.vue";
import LangToggle from "./LangToggle.vue";
import LoginDialog from "./LoginDialog.vue";

const { currentUser: user } = storeToRefs(useAuthStore());
const loginOpen = ref(false);
</script>
