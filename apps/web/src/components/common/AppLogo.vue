<template>
  <div class="h-8 cursor-pointer max-w-[150px]" @click="handleClick">
    <img
      src="https://pethaven.vn/source/imges/logo_pet.png"
      alt="app_logo"
      class="w-full h-full object-cover "
    />
  </div>
</template>

<script lang="ts" setup>
import { useRouter } from "vue-router";

const props = defineProps<{
  isCollapsed?: boolean;
}>();

const router = useRouter();

const handleClick = () => {
  router.push({ name: "home" });
};
</script>
