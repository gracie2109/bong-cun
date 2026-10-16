<script setup lang="ts">
import { Notification } from "@/components/common";
import BaseAvatar from "@/components/common/BaseAvatar.vue";
import SwitchLang from "@/components/common/SwitchLang.vue";
import { SidebarTrigger } from "@/components/ui/sidebar";
</script>

<template>
  <header
    id="header"
    class="sticky top-0 z-30 flex h-14 shrink-0 items-center gap-3 border-b bg-white/90 px-4 backdrop-blur md:px-6"
  >
    <SidebarTrigger class="-ml-1 text-muted-foreground" />
    <span class="h-5 w-px bg-border" />
    <div class="min-w-0 flex-1 truncate text-sm [&_h1]:text-sm">
      <slot />
    </div>
    <div class="flex items-center gap-4">
      <Notification />
      <SwitchLang />
      <BaseAvatar />
    </div>
  </header>
</template>
