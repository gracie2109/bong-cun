<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <ShieldCheck class="size-4 text-primary" />
      {{ $t("rbac.title") }}
    </h1>
  </Header>

  <ContentWrap>
    <div class="relative top-10 space-y-5 pb-24">
      <div class="flex flex-wrap items-start justify-between gap-4">
        <div class="max-w-2xl space-y-1.5">
          <span
            v-if="eyebrow"
            class="inline-block rounded-md bg-primary/10 px-2 py-0.5 text-[11px] font-bold uppercase tracking-wider text-primary"
          >
            {{ eyebrow }}
          </span>
          <h2 class="text-3xl font-bold tracking-tight">{{ title ?? $t("rbac.title") }}</h2>
          <p class="text-sm text-muted-foreground">{{ subtitle ?? $t("rbac.subtitle") }}</p>
        </div>
        <div class="flex flex-wrap items-center gap-2">
          <slot name="actions" />
        </div>
      </div>

      <div class="flex flex-wrap items-stretch gap-3">
        <nav class="flex flex-wrap gap-1 rounded-xl border bg-muted/50 p-1">
          <router-link
            v-for="tab in tabs"
            :key="tab.name"
            :to="{ name: tab.name }"
            class="flex items-center gap-2 rounded-lg px-4 py-2 text-sm font-semibold transition-colors"
            :class="route.name === tab.name ? 'bg-white text-foreground shadow-sm' : 'text-muted-foreground hover:text-foreground'"
          >
            <Icon :icon="tab.icon" class="size-4" :class="route.name === tab.name ? 'text-primary' : ''" />
            {{ $t(tab.label) }}
            <span
              v-if="tab.count !== null"
              class="rounded-full px-2 py-0.5 text-[11px] font-semibold"
              :class="route.name === tab.name ? 'bg-primary/10 text-primary' : 'bg-muted text-muted-foreground'"
            >
              {{ tab.count }}
            </span>
          </router-link>
        </nav>
        <slot name="summary" />
      </div>

      <slot />
    </div>
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Icon } from "@iconify/vue";
import { ShieldCheck } from "lucide-vue-next";
import { useRoute } from "vue-router";
import { usePermissionsList } from "@/queries/permissions";
import { useRolesList } from "@/queries/roles";
import { ContentWrap, Header } from "@/views/admin/components";

defineProps<{ eyebrow?: string; title?: string; subtitle?: string }>();

const route = useRoute();
// Shared with the page below through the query cache, so the counts cost no extra request.
const rolesQuery = useRolesList();
const permissionsQuery = usePermissionsList();

const tabs = computed(() => [
  { name: "settings", icon: "lucide:user-cog", label: "rbac.nav.roles", count: rolesQuery.data.value?.length ?? null },
  {
    name: "permissions",
    icon: "lucide:key-round",
    label: "rbac.nav.permissions",
    count: permissionsQuery.data.value?.length ?? null,
  },
  { name: "permissionMatrix", icon: "lucide:grid-3x3", label: "rbac.nav.matrix", count: null },
]);
</script>
