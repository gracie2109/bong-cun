<template>
  <div class="space-y-3 rounded-xl border bg-white p-4">
    <h3 class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
      {{ $t("petCare.pets.detail.owners") }}
    </h3>
    <p v-if="owners.length === 0" class="text-sm text-muted-foreground">
      {{ $t("petCare.pets.noOwner") }}
    </p>
    <ul class="divide-y">
      <li v-for="owner in owners" :key="owner.customer.id" class="flex items-center gap-3 py-2">
        <Avatar class="size-9">
          <AvatarFallback class="bg-primary/15 text-sm font-semibold text-primary">
            {{ initials(owner.customer.fullName) }}
          </AvatarFallback>
        </Avatar>
        <div class="min-w-0 flex-1">
          <p class="truncate font-semibold">{{ owner.customer.fullName }}</p>
          <p class="text-xs text-muted-foreground">{{ owner.customer.phone }}</p>
        </div>
        <Button
          v-if="canUpdate && !owner.customer.userId"
          size="sm"
          variant="ghost"
          class="h-7 px-2 text-xs"
          @click="linking = owner.customer"
        >
          <Link2 class="mr-1 size-3.5" />
          {{ $t("petCare.pets.link.button") }}
        </Button>
        <span v-else-if="owner.customer.userId" class="text-[11px] text-muted-foreground">
          {{ $t("petCare.pets.link.linked") }}
        </span>
        <span class="rounded-full bg-primary/10 px-2 py-0.5 text-[11px] font-medium text-primary">
          {{ owner.role === "primary" ? $t("petCare.pets.detail.primary") : $t("petCare.pets.detail.coOwner") }}
        </span>
      </li>
    </ul>
    <p class="text-xs text-muted-foreground">{{ $t("petCare.pets.detail.ownersNote") }}</p>
    <LinkAccountDialog v-if="linking" :open="true" :customer="linking" @update:open="linking = null" />
  </div>
</template>

<script lang="ts" setup>
import { ref } from "vue";
import { Link2 } from "lucide-vue-next";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import type { Customer } from "@/repositories/customers";
import type { PetOwner } from "@/repositories/pets";
import { initials } from "../format";
import LinkAccountDialog from "./link/LinkAccountDialog.vue";

defineProps<{ owners: PetOwner[]; canUpdate?: boolean }>();

const linking = ref<Customer | null>(null);
</script>
