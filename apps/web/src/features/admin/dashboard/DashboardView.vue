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
          <DashboardToolbar
            v-if="active"
            :editing="editor.editing.value"
            :is-dirty="editor.isDirty.value"
            :saving="editor.saving.value"
            :can-edit="branches.length > 0"
            :saved-at="savedAt"
            @start="editor.start"
            @save="editor.persist"
            @cancel="editor.cancel"
            @reset="editor.restoreDefault"
          />
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
      <DashboardItems v-else-if="active" :items="visibleItems" :editing="editor.editing.value" @update:items="onItems">
        <template #default="{ item }">
          <GridItemFrame
            :key="`${active.key}-${activeScope.kind}-${activeScope.branchId}`"
            :item="item"
            :editing="editor.editing.value"
            @move="(step) => actions.move(item.id, step)"
            @resize="(preset) => actions.resize(item.id, preset)"
            @remove="actions.remove(item.id)"
          />
        </template>
      </DashboardItems>
      <LayoutConflictDialog :open="editor.conflict.value" @overwrite="editor.overwrite" @reload="editor.reload" />

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
import { format } from "date-fns";
import type { SavedItem } from "@bongcun/core/dashboard";
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
import DashboardItems from "./layout/DashboardItems.vue";
import DashboardToolbar from "./layout/DashboardToolbar.vue";
import GridItemFrame from "./layout/GridItemFrame.vue";
import LayoutConflictDialog from "./layout/LayoutConflictDialog.vue";
import { useDashboardLayout } from "./layout/useDashboardLayout";
import { useItemActions } from "./layout/useItemActions";
import { useLayoutEditor } from "./layout/useLayoutEditor";
import { useEditEscape } from "./layout/useEditEscape";
import { useUnsavedGuard } from "./layout/useUnsavedGuard";
import { useVisibleItems } from "./layout/useVisibleItems";
import { useDashboardScope } from "./useDashboardScope";
import { useDashboardSelection } from "./useDashboardSelection";

const auth = useAuthStore();
const { scope, branches, canPickAll, select } = useDashboardScope();
const { visible, active, open } = useDashboardSelection(scope);

// "All branches" falls back to the working branch on a dashboard that cannot add branches up.
const activeScope = computed(() => (active.value ? scopeFor(active.value, scope.value) : scope.value));
provideWidgetScope(activeScope);

const saved = useDashboardLayout(active);
const editor = useLayoutEditor(computed(() => active.value?.key ?? null), saved);
const { visible: visibleItems, merge } = useVisibleItems(editor.items, activeScope);
const actions = useItemActions(editor.items, editor.update);
const onItems = (changed: SavedItem[]) => editor.update(merge(changed));
useUnsavedGuard(editor.isDirty);
useEditEscape(editor);
const savedAt = computed(() => (saved.updatedAt.value ? format(new Date(saved.updatedAt.value), "HH:mm dd/MM") : ""));

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
