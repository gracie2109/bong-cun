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

      <DropdownMenuLabel>{{  currentUser?.email ?? ""}}</DropdownMenuLabel>
      <DropdownMenuSeparator />
      <DropdownMenuGroup>
        <DropdownMenuItem @click="goToProfile">
          <User class="mr-2 h-4 w-4" />
          <span>Profile</span>
          <DropdownMenuShortcut>⇧⌘P</DropdownMenuShortcut>
        </DropdownMenuItem>
      </DropdownMenuGroup>

      <DropdownMenuSeparator />
      <DropdownMenuItem @click="handleLogout">
        <LogOut class="mr-2 h-4 w-4" />
        <span>Log out</span>
        <DropdownMenuShortcut>⇧⌘Q</DropdownMenuShortcut>
      </DropdownMenuItem>
    </DropdownMenuContent>
  </DropdownMenu>
</template>

<script lang="ts" setup>
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuShortcut,
  DropdownMenuTrigger
} from "@/components/ui/dropdown-menu";
import { LogOut, User } from "lucide-vue-next";
import { useAuthStore } from "@/stores";
import { storeToRefs } from "pinia";
import { computed } from "vue";
import { useRouter } from "vue-router"
const store = useAuthStore();
const router = useRouter();
const { currentUser } = storeToRefs(store);
function handleLogout() {
  store.signoutHdl();
}

function goToProfile () {
  router.push({name: 'profile'})
}
// No photo: leave src empty so the fallback icon shows instead of a remote placeholder.
const avatar = computed(() => currentUser.value?.photoURL || "")
</script>
