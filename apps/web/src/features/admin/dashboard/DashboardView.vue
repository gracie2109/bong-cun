<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <LayoutDashboard class="size-4 text-primary" />
      {{ $t("adminNav.dashboard") }}
    </h1>
  </Header>

  <ContentWrap>
    <div class="space-y-5">
      <div class="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 class="text-3xl font-bold tracking-tight">{{ $t("adminNav.welcome", { name: userName }) }}</h2>
          <p class="text-sm text-muted-foreground">{{ $t("adminNav.welcomeHint") }}</p>
        </div>
        <div class="flex flex-wrap items-center gap-2">
          <DashboardSwitcher :items="visible" :active-key="active?.key" @select="open" />
          <DashboardScopePicker
            :scope="activeScope"
            :branches="branches"
            :allow-all="canPickAll && !!active?.scopes.includes('all')"
            @select="select"
          />
        </div>
      </div>

      <p v-if="!branches.length" class="rounded-xl border bg-white px-4 py-10 text-center text-sm text-muted-foreground">
        {{ $t("dashboard.noBranch") }}
      </p>
      <div v-else-if="active" class="grid gap-4 lg:grid-cols-2">
        <component
          :is="widget.component"
          v-for="widget in active.widgets"
          :key="`${active.key}-${widget.key}-${activeScope.kind}-${activeScope.branchId}`"
          :class="widget.span === 2 && 'lg:col-span-2'"
        />
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
import { canOpenAdminRoute } from "@bongcun/core/auth";
import { ADMIN_NAV_SECTIONS } from "@/lib/navigations";
import { useAuthStore } from "@/stores";
import { ContentWrap, Header } from "@/features/admin/components";
import DashboardScopePicker from "./DashboardScopePicker.vue";
import DashboardSwitcher from "./DashboardSwitcher.vue";
import { scopeFor } from "./dashboardRules";
import { provideWidgetScope } from "./kit/widgetScope";
import { useDashboardScope } from "./useDashboardScope";
import { useDashboardSelection } from "./useDashboardSelection";

const auth = useAuthStore();
const { scope, branches, canPickAll, select } = useDashboardScope();
const { visible, active, open } = useDashboardSelection(scope);

// "All branches" falls back to the working branch on a dashboard that cannot add branches up.
const activeScope = computed(() => (active.value ? scopeFor(active.value, scope.value) : scope.value));
provideWidgetScope(activeScope);

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
