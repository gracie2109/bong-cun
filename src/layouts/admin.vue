<script setup lang="ts">
import { LogOut, PawPrint } from "lucide-vue-next";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarGroupLabel,
  SidebarHeader,
  SidebarInset,
  SidebarMenu,
  SidebarProvider,
  SidebarRail,
} from "@/components/ui/sidebar";
import Nav from "@/components/layout/admin/Nav.vue";
import { canOpenAdminRoute } from "@/lib/access";
import { ADMIN_NAV_SECTIONS } from "@/lib/navigations";
import { useAppStore, useAuthStore } from "@/stores";
import { initials } from "@/views/admin/pets/format";

// The admin palette lives on <html> (see index.css) so teleported sheets and dialogs get it too.
onMounted(() => document.documentElement.classList.add("admin-theme"));
onBeforeUnmount(() => document.documentElement.classList.remove("admin-theme"));

const auth = useAuthStore();
const app = useAppStore();

// Menu items the staff member has VIEW on; a section disappears when it has none.
const sections = computed(() => {
  const grants = auth.adminGrants ?? {};
  return ADMIN_NAV_SECTIONS.map((section) => ({
    ...section,
    items: section.items.filter((item) => canOpenAdminRoute(grants, item.name)),
  })).filter((section) => section.items.length > 0);
});

const userName = computed(
  () => auth.currentUser?.fullName || auth.currentUser?.displayName || auth.currentUser?.email || ""
);
</script>

<template>
  <SidebarProvider :open="app.sidebarOpen" @update:open="app.setSidebarOpen">
    <Sidebar collapsible="icon" class="border-r">
      <SidebarHeader class="border-b px-3 py-4 group-data-[collapsible=icon]:px-2">
        <router-link :to="{ name: 'dashboard' }" class="flex items-center gap-3">
          <span class="flex size-9 shrink-0 items-center justify-center rounded-xl bg-primary text-primary-foreground">
            <PawPrint class="size-5" />
          </span>
          <span class="min-w-0 group-data-[collapsible=icon]:hidden">
            <span class="flex items-center gap-1.5 text-base font-bold leading-tight">
              BongCun
              <span class="rounded bg-primary/10 px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wide text-primary">
                Admin
              </span>
            </span>
            <span class="block truncate text-xs text-muted-foreground">Pet Care &amp; Grooming</span>
          </span>
        </router-link>
      </SidebarHeader>

      <SidebarContent class="gap-0 py-2">
        <SidebarGroup v-for="section in sections" :key="section.title" class="py-1.5">
          <SidebarGroupLabel class="h-7 px-3 text-[11px] font-bold uppercase tracking-wider text-muted-foreground">
            {{ $t(section.title) }}
          </SidebarGroupLabel>
          <SidebarMenu class="gap-0.5">
            <Nav :items="section.items" />
          </SidebarMenu>
        </SidebarGroup>
      </SidebarContent>

      <SidebarFooter class="border-t p-3 group-data-[collapsible=icon]:p-2">
        <div class="flex items-center gap-3 rounded-xl border bg-muted/40 p-2 group-data-[collapsible=icon]:border-0 group-data-[collapsible=icon]:bg-transparent group-data-[collapsible=icon]:p-0">
          <Avatar class="size-9 shrink-0">
            <AvatarImage v-if="auth.currentUser?.photoURL" :src="auth.currentUser.photoURL" />
            <AvatarFallback class="bg-primary/10 text-xs font-semibold text-primary">{{ initials(userName || "?") }}</AvatarFallback>
          </Avatar>
          <div class="min-w-0 flex-1 group-data-[collapsible=icon]:hidden">
            <p class="truncate text-sm font-semibold">{{ userName }}</p>
            <p class="truncate text-xs text-muted-foreground">{{ auth.role }}</p>
          </div>
          <button
            type="button"
            class="rounded-md p-1.5 text-muted-foreground transition-colors hover:bg-white hover:text-red-600 group-data-[collapsible=icon]:hidden"
            :aria-label="$t('adminNav.logout')"
            :title="$t('adminNav.logout')"
            @click="auth.signoutHdl()"
          >
            <LogOut class="size-4" />
          </button>
        </div>
      </SidebarFooter>
      <SidebarRail />
    </Sidebar>

    <SidebarInset class="min-w-0 bg-background">
      <slot />
    </SidebarInset>
  </SidebarProvider>
</template>
