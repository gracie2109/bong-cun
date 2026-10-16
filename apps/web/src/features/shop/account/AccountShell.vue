<template>
  <div class="container py-6">
    <h1 class="mb-4 text-2xl font-bold">{{ $t("client.account.title") }}</h1>
    <div class="grid gap-6 lg:grid-cols-[220px_1fr]">
      <aside class="self-start rounded-xl border bg-white p-2 lg:p-3">
        <AccountNav />
      </aside>
      <div class="min-w-0">
        <slot />
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import AccountNav from "./components/AccountNav.vue";
</script>
