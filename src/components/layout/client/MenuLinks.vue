<template>
  <ul :class="clsx(`flex relative font-semibold list-none ${navLinksClass}`,
  
  )
    ">
    <li :class="langClass">
      <SwitchLang />
    </li>
    <MenuLink v-for="link in navigation.clientNav" :key="link.text" :link="link" />
  </ul>
</template>

<script setup lang="ts">
import { computed, ref } from "vue";
import { MenuLink } from "@/components/common";
import clsx from "clsx";
import { useRoute } from "vue-router";
import { navigation } from "@/lib/navigations";
import SwitchLang from "@/components/common/SwitchLang.vue";

const props = withDefaults(
  defineProps<{
    type?: string;
  }>(),
  {
    type: "mobile",
  }
);

const route = useRoute();

const navLinksClass = computed<string>(() => {
  return props.type === "mobile"
    ? "flex-col space-y-6 h-screen px-8 py-28 landscape:justify-around"
    : "items-center gap-x-8 xl:gap-x-14";
});

const langClass = computed(() => {
  return props.type === "mobile" ? "block" : 'hidden'
})
</script>
