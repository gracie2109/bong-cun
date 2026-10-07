<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <LayoutDashboard class="size-4 text-primary" />
      {{ $t("adminNav.dashboard") }}
    </h1>
  </Header>

  <ContentWrap>
    <div class="space-y-5">
      <div>
        <h2 class="text-3xl font-bold tracking-tight">{{ $t("adminNav.welcome", { name: userName }) }}</h2>
        <p class="text-sm text-muted-foreground">{{ $t("adminNav.welcomeHint") }}</p>
      </div>

      <div v-if="shortcuts.length" class="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <router-link
          v-for="item in shortcuts"
          :key="item.name"
          :to="{ name: item.name }"
          class="flex items-center gap-3 rounded-xl border bg-white p-4 transition-colors hover:border-primary hover:bg-primary/5"
        >
          <span class="flex size-10 items-center justify-center rounded-lg bg-primary/10 text-primary">
            <Icon :icon="item.icon || 'lucide:dot'" class="size-5" />
          </span>
          <span class="font-semibold">{{ $t(item.title) }}</span>
        </router-link>
      </div>
      <p v-else class="rounded-xl border bg-white px-4 py-10 text-center text-sm text-muted-foreground">
        {{ $t("adminNav.noAccess") }}
      </p>
    </div>
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Icon } from "@iconify/vue";
import { LayoutDashboard } from "lucide-vue-next";
import { canOpenAdminRoute } from "@/lib/access";
import { ADMIN_NAV_SECTIONS } from "@/lib/navigations";
import { useAuthStore } from "@/stores";
import { ContentWrap, Header } from "@/views/admin/components";

const auth = useAuthStore();

const userName = computed(
  () => auth.currentUser?.fullName || auth.currentUser?.displayName || auth.currentUser?.email || ""
);

// The pages this staff member can open, as quick links.
const shortcuts = computed(() =>
  ADMIN_NAV_SECTIONS.flatMap((section) => section.items).filter(
    (item) => item.name !== "dashboard" && canOpenAdminRoute(auth.adminGrants ?? {}, item.name)
  )
);
</script>
