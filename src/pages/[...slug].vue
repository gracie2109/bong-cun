<script setup lang="ts">
import NotFoundPage from "@/components/NotFoundPage.vue";
import { PAGE_LAYOUT } from "@/lib/constants";

definePageMeta({
  titleKey: "notFound",
  layout: PAGE_LAYOUT.NO_LAYOUT,
  noindex: true,
});

// Unknown URLs answer with a real 404 instead of a 200 (or a redirect for guests).
const event = useRequestEvent();
if (event) setResponseStatus(event, 404);
</script>

<template>
  <NotFoundPage />
</template>
