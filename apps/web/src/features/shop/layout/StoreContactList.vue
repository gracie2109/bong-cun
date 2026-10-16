<template>
  <ul class="space-y-2">
    <li class="flex items-start gap-2">
      <MapPin class="mt-0.5 size-4 shrink-0 text-brand" />
      <span>{{ STORE_INFO.address }}</span>
    </li>
    <li class="flex items-start gap-2">
      <Phone class="mt-0.5 size-4 shrink-0 text-brand" />
      <a :href="`tel:${STORE_INFO.phone}`" class="hover:underline">{{ STORE_INFO.phone }}</a>
    </li>
    <li class="flex items-start gap-2">
      <Mail class="mt-0.5 size-4 shrink-0 text-brand" />
      <a :href="`mailto:${STORE_INFO.email}`" class="hover:underline">{{ STORE_INFO.email }}</a>
    </li>
    <li class="flex items-start gap-2">
      <Clock class="mt-0.5 size-4 shrink-0 text-brand" />
      <span>{{ STORE_INFO.hours }}</span>
    </li>
  </ul>
</template>

<script setup lang="ts">
import { Clock, Mail, MapPin, Phone } from "lucide-vue-next";
import { STORE_INFO } from "@/config/storeInfo";
</script>
