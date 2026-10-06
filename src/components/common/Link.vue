<template>
  <li class="text-xl lg:text-base">
    <router-link :to="{ name: link.name }" class="transition-colors hover:text-custom-primary" :class="{
      'text-primary': route.name?.toString().includes(props.link.name)
    }">
      {{ link.text }}
    </router-link>
  </li>
</template>

<script setup lang="ts">
import { useRoute } from "vue-router";
const route = useRoute();

const props = defineProps({
  link: {
    type: Object,
    required: true,
  },
});
</script>
