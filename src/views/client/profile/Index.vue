<template>
  <div class="w-full space-y-8 mt-5 container">
    <template v-if="currentUser">
      <Transition mode="out-in">
        <div class="w-full flex gap-x-8 items-center max-w-screen-sm sticky top-0 bg-white z-10" id="profile_tab">
          <p v-for="i in navigation.profileNav" :key="i.label" :to="i.path" :class="{
            ' text-custom-primary/80 border-b border-primary': i.label === activeKey,
          }" class="font-semibold capitalize inline-block w-1/3 text-center py-1.5 cursor-pointer border-b"
            @click="() => (activeKey = i.label)">
            {{ i.label }}
          </p>
        </div>
      </Transition>

      <div id="render_profile_tab">
        <GeneralInfo v-if="activeKey === PROFILE_KEYS.GENERAL" />
        <MyOrders v-if="activeKey === PROFILE_KEYS.ORDERS" />
        <ProfileAddress v-if="activeKey === PROFILE_KEYS.ADDRESS" />

      </div>
    </template>
    <template v-else>
      <div class="container ">
          <div class="grid place-content-center w-full h-full">
            Please login first
          </div>
      </div>
    </template>
  </div>
</template>

<script lang="ts" setup>
import { navigation, PROFILE_KEYS } from "@/lib/navigations";
import { ref } from "vue";
import GeneralInfo from "./components/GeneralInfo/Index.vue";
import MyOrders from "./components/Orders/Index.vue";
import ProfileAddress from "./components/Address/Index.vue";

import { useAuthStore } from "@/stores";
import { storeToRefs } from "pinia";
const store = useAuthStore();
const { currentUser } = storeToRefs(store);
const activeKey = ref(navigation.profileNav[0]["key"]);

</script>
