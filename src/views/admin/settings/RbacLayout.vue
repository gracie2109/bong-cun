<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <ShieldCheck class="size-4 text-primary" />
      {{ $t("rbac.title") }}
    </h1>
  </Header>

  <ContentWrap>
    <div class="relative top-10 space-y-5">
      <div class="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 class="text-2xl font-bold">{{ $t("rbac.title") }}</h2>
          <p class="text-sm text-muted-foreground">{{ $t("rbac.subtitle") }}</p>
        </div>
        <slot name="actions" />
      </div>

      <nav class="flex flex-wrap gap-1 rounded-xl border bg-white p-1">
        <router-link
          v-for="tab in tabs"
          :key="tab.name"
          :to="{ name: tab.name }"
          class="flex items-center gap-2 rounded-lg px-3 py-2 text-sm font-semibold transition-colors"
          :class="route.name === tab.name ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:bg-muted'"
        >
          <Icon :icon="tab.icon" class="size-4" />
          {{ $t(tab.label) }}
        </router-link>
      </nav>

      <slot />
    </div>
  </ContentWrap>
</template>

<script lang="ts" setup>
import { Icon } from "@iconify/vue";
import { ShieldCheck } from "lucide-vue-next";
import { useRoute } from "vue-router";
import { ContentWrap, Header } from "@/views/admin/components";

const route = useRoute();

const tabs = [
  { name: "settings", icon: "lucide:user-cog", label: "rbac.nav.roles" },
  { name: "permissions", icon: "lucide:key-round", label: "rbac.nav.permissions" },
  { name: "permissionMatrix", icon: "lucide:grid-3x3", label: "rbac.nav.matrix" },
];
</script>
