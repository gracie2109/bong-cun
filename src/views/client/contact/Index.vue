<template>
  <div class="container space-y-8 py-10">
    <header class="space-y-2">
      <h1 class="text-3xl font-bold text-primary">{{ $t("client.contact.title") }}</h1>
      <p class="text-muted-foreground">{{ $t("client.contact.subtitle") }}</p>
    </header>
    <div class="grid gap-8 lg:grid-cols-2">
      <div class="space-y-4 rounded-xl border p-6">
        <StoreContactList />
        <Button as-child>
          <a :href="`tel:${STORE_INFO.phone}`">{{ $t("client.contact.call") }}</a>
        </Button>
      </div>
      <div class="h-[400px] overflow-hidden rounded-xl border">
        <iframe
          :src="STORE_INFO.mapEmbedUrl"
          :title="$t('client.contact.map')"
          class="h-full w-full"
          loading="lazy"
          referrerpolicy="no-referrer-when-downgrade"
        ></iframe>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { Button } from "@/components/ui/button";
import { STORE_INFO } from "@/config/storeInfo";
import StoreContactList from "@/views/client/layout/StoreContactList.vue";
</script>
