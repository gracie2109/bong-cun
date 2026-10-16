<template>
  <tr
    class="border-t cursor-pointer transition-colors hover:bg-muted/40"
    :class="{ 'bg-primary/10 hover:bg-primary/10': selected }"
    @click="emit('select')"
  >
    <td class="px-4 py-3">
      <div class="flex items-center gap-3 min-w-0">
        <Avatar class="size-10">
          <AvatarImage v-if="customer.photoURL" :src="customer.photoURL" />
          <AvatarFallback class="bg-primary/15 text-primary font-semibold">
            {{ initials(customer) }}
          </AvatarFallback>
        </Avatar>
        <div class="min-w-0">
          <p class="flex items-center gap-2 font-semibold">
            <span class="truncate">{{ customerName(customer) }}</span>
            <span
              v-if="isNewCustomer(customer.createdAt)"
              class="shrink-0 rounded-full bg-emerald-100 text-emerald-700 px-2 py-0.5 text-[10px] font-semibold uppercase"
            >
              {{ $t("pageFields.customers.badgeNew") }}
            </span>
          </p>
          <p class="text-xs text-muted-foreground truncate">
            {{ customer.phoneNumber || customer.email }}
          </p>
        </div>
      </div>
    </td>
    <td class="px-4 py-3 text-right whitespace-nowrap">
      <p class="font-bold">{{ formatPrice(stats.totalSpent) }}</p>
      <p class="text-xs text-muted-foreground">
        {{ $t("pageFields.customers.serviceCount", { n: stats.serviceCount }) }}
      </p>
    </td>
    <td class="px-4 py-3">
      <template v-if="stats.lastVisit">
        <p class="font-medium">
          {{ formatVisit(stats.lastVisit) }}
        </p>
        <p class="text-xs text-muted-foreground truncate max-w-40">
          {{ stats.lastServiceName }}
        </p>
      </template>
      <span v-else class="text-xs text-muted-foreground">
        {{ $t("pageFields.customers.neverVisited") }}
      </span>
    </td>
    <td class="px-4 py-3 text-right">
      <Button size="sm" :variant="selected ? 'default' : 'outline'" @click.stop="emit('select')">
        {{ $t("pageFields.customers.viewProfile") }}
      </Button>
    </td>
  </tr>
</template>

<script lang="ts" setup>
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { formatPrice } from "@/lib/utils";
import type { IUser } from "@/types/user.type";
import { customerName, formatVisit, initials } from "../customer-format";
import { isNewCustomer, type CustomerStats } from "../customer-stats";

defineProps<{
  customer: IUser;
  stats: CustomerStats;
  selected: boolean;
}>();

const emit = defineEmits<{ select: [] }>();
</script>
