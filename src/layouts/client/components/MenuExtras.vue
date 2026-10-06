<template>
  <div class="flex items-center gap-x-6 md:gap-x-4 will-change-auto">
    <div class="hidden lg:block">
      <SwitchLang />
    </div>

    <Separator class="hidden !h-5 lg:block z-[10]" orientation="vertical" />
    <CartMenu :type="String(route.name)" />
    <div v-if="user" class="z-[10]">
      <BaseAvatar />
    </div>
    <div v-else class="z-[10] cursor-pointer">
      <p @click="open = !open">Login</p>
    </div>

    <MenuButton @toggle-menu="emit('toggleMenu')" />
  </div>
  <Dialog :open="open" @update:open="open = !open" class="w-full">
    <DialogContent class="sm:w-[550px] w-[90%] h-auto max-h-[690px]   rounded-lg">
      <LoginView
        v-if="!component || component?.includes('login')"
        @directPath="directPath"
        @close-dialog="() => (open = !open)"
      />
      <RegisterView
        v-else-if="component?.includes('register')"
        @directPath="directPath"
        @close-dialog="() => (open = !open)"
      />
      <ForgotPassView
        v-else
        @directPath="directPath"
        @close-dialog="() => (open = !open)"
      />
    </DialogContent>
  </Dialog>
</template>

<script lang="ts" setup>
import { BaseAvatar, SwitchLang } from "@/components/common";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import { Separator } from "@/components/ui/separator";
import ForgotPassView from "@/views/auth/ForgotPassView.vue";
import LoginView from "@/views/auth/LoginView.vue";
import RegisterView from "@/views/auth/RegisterView.vue";
import { ref } from "vue";
import { storeToRefs } from "pinia";
import { useAuthStore } from "@/stores";
import { useRoute } from "vue-router";
import MenuButton from "../components/MenuButton.vue";
import CartMenu from "./CartMenu.vue";

const emit = defineEmits(["toggleMenu"]);
const route = useRoute();
const component = ref<string | null>(null);
const { currentUser: user } = storeToRefs(useAuthStore());
const open = ref(false);
const directPath = (value: any) => {
  component.value = value;
};
</script>
