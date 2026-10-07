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
import { ADMIN_NAVIGATOR } from "@/lib/navigations";

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
            <Nav :items="ADMIN_NAVIGATOR"/>
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
