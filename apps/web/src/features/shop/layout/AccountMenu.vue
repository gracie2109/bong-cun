<template>
  <DropdownMenu>
    <DropdownMenuTrigger as-child class="cursor-pointer">
      <Avatar size="xs" class="ring-1 ring-border">
        <AvatarImage :src="avatar" :alt="currentUser?.displayName ?? ''" />
        <AvatarFallback>
          <User class="size-4 text-muted-foreground" />
        </AvatarFallback>
      </Avatar>
    </DropdownMenuTrigger>
    <DropdownMenuContent class="w-56">
      <DropdownMenuLabel class="truncate">{{ currentUser?.email ?? "" }}</DropdownMenuLabel>
      <DropdownMenuSeparator />
      <DropdownMenuItem
        v-for="item in ACCOUNT_MENU_ITEMS"
        :key="item.name"
        @click="router.push({ name: item.name })"
      >
        <User class="mr-2 h-4 w-4" />
        <span>{{ $t(item.label) }}</span>
      </DropdownMenuItem>
      <DropdownMenuItem v-if="isStaff && !isNativeApp" @click="router.push({ name: 'dashboard' })">
        <LayoutDashboard class="mr-2 h-4 w-4" />
        <span>{{ $t("client.menu.admin") }}</span>
      </DropdownMenuItem>
      <DropdownMenuSeparator />
      <DropdownMenuItem @click="store.signoutHdl()">
        <LogOut class="mr-2 h-4 w-4" />
        <span>{{ $t("client.menu.logout") }}</span>
      </DropdownMenuItem>
    </DropdownMenuContent>
  </DropdownMenu>
</template>

<script lang="ts" setup>
import { useAppTarget } from "@/features/native";
import { computed } from "vue";
import { storeToRefs } from "pinia";
import { useRouter } from "vue-router";
import { LayoutDashboard, LogOut, User } from "lucide-vue-next";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { ACCOUNT_MENU_ITEMS } from "@/lib/clientAccountMenu";
import { useAuthStore } from "@/stores";

const { isNativeApp } = useAppTarget();

const store = useAuthStore();
const router = useRouter();
const { currentUser, isStaff } = storeToRefs(store);
// No photo: leave src empty so the fallback icon shows instead of a remote placeholder.
const avatar = computed(() => currentUser.value?.photoURL || "");
</script>
