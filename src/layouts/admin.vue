<script setup lang="ts">
import AppLogo from "@/components/common/AppLogo.vue";
import {
  Sidebar,
  SidebarContent,
  SidebarGroup, 
  SidebarHeader,
  SidebarInset,
  SidebarMenu,
  SidebarMenuItem,
  SidebarProvider,
  SidebarRail,
  SidebarTrigger,
} from "@/components/ui/sidebar";
import Nav from "@/components/layout/admin/Nav.vue";
import { canOpenAdminRoute } from "@/lib/access";
import { ADMIN_NAVIGATOR } from "@/lib/navigations";
import { useAuthStore } from "@/stores";
import type { LinkProp } from "@/types";

const auth = useAuthStore();

// Menu items the staff member has VIEW on; a group stays while any child is visible.
const visibleNav = computed(() => {
  const grants = auth.adminGrants ?? {};
  const visible = (items: LinkProp[]): LinkProp[] =>
    items.flatMap((item) => {
      if (!item.children?.length) return canOpenAdminRoute(grants, item.name) ? [item] : [];
      const children = visible(item.children);
      return children.length ? [{ ...item, children }] : [];
    });
  return visible(ADMIN_NAVIGATOR);
});

// The admin palette lives on <html> (see index.css) so teleported sheets and dialogs get it too.
onMounted(() => document.documentElement.classList.add("admin-theme"));
onBeforeUnmount(() => document.documentElement.classList.remove("admin-theme"));

</script>

<template>
  <SidebarProvider>
    <Sidebar collapsible="icon">
      <SidebarHeader>
        <SidebarMenu>
          <SidebarMenuItem>
            <AppLogo />
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarHeader>

      <SidebarContent>
        <SidebarGroup>
          <SidebarMenu class="mt-5">
            <Nav :items="visibleNav" />
          </SidebarMenu>
        </SidebarGroup>
      </SidebarContent>
      <SidebarRail />
    </Sidebar>
    <SidebarInset>
      <div class="relative">
        <div class="relative -left-3 top-[25rem]">
          <SidebarTrigger class="-ml-1" />
        </div>
        <div class="relative top-[-2rem]">
          <slot />
        </div>
      </div>
    </SidebarInset>
  </SidebarProvider>
</template>
