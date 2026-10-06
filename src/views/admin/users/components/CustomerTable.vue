<template>
  <div class="rounded-xl border bg-white overflow-hidden">
    <div class="flex items-center justify-between gap-3 px-4 py-3 bg-muted/40 border-b">
      <div class="flex items-center gap-2 min-w-0">
        <h2 class="text-xs font-semibold uppercase tracking-wide">
          {{ $t("pageFields.customers.listTitle") }}
        </h2>
        <span class="rounded-full bg-primary/10 text-primary px-2 py-0.5 text-[11px] font-medium">
          {{ $t("pageFields.customers.showing", { count: customers.length, total }) }}
        </span>
      </div>
      <div class="flex items-center gap-1 text-xs text-muted-foreground">
        <Button
          variant="ghost"
          size="icon"
          class="size-7"
          :disabled="page <= 1 || loading"
          @click="$emit('page', page - 1)"
        >
          <ChevronLeft class="size-4" />
        </Button>
        <span>{{ $t("pageFields.customers.pageOf", { page, pages: pageCount }) }}</span>
        <Button
          variant="ghost"
          size="icon"
          class="size-7"
          :disabled="page >= pageCount || loading"
          @click="$emit('page', page + 1)"
        >
          <ChevronRight class="size-4" />
        </Button>
      </div>
    </div>

    <div class="overflow-x-auto">
      <table class="w-full text-sm">
        <thead>
          <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
            <th class="px-4 py-3 font-semibold">{{ $t("pageFields.customers.col.customer") }}</th>
            <th class="px-4 py-3 font-semibold text-right">
              {{ $t("pageFields.customers.col.spent") }}
            </th>
            <th class="px-4 py-3 font-semibold">{{ $t("pageFields.customers.col.lastVisit") }}</th>
            <th class="px-4 py-3 font-semibold text-right">
              {{ $t("pageFields.customers.col.actions") }}
            </th>
          </tr>
        </thead>
        <tbody>
          <template v-if="loading && customers.length === 0">
            <tr v-for="i in 4" :key="i" class="border-t">
              <td colspan="4" class="px-4 py-3"><Skeleton class="h-10 w-full" /></td>
            </tr>
          </template>
          <tr v-else-if="customers.length === 0">
            <td colspan="4" class="px-4 py-10 text-center text-muted-foreground">
              {{ $t("pageFields.customers.empty") }}
            </td>
          </tr>
          <tr
            v-for="customer in customers"
            :key="customer.userId"
            class="border-t cursor-pointer transition-colors hover:bg-muted/40"
            :class="{ 'bg-primary/10 hover:bg-primary/10': customer.userId === selectedId }"
            @click="$emit('select', customer.userId)"
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
              <p class="font-bold">{{ formatPrice(statsOf(stats, customer.userId).totalSpent) }}</p>
              <p class="text-xs text-muted-foreground">
                {{
                  $t("pageFields.customers.serviceCount", {
                    n: statsOf(stats, customer.userId).serviceCount,
                  })
                }}
              </p>
            </td>
            <td class="px-4 py-3">
              <template v-if="statsOf(stats, customer.userId).lastVisit">
                <p class="font-medium">
                  {{ formatVisit(statsOf(stats, customer.userId).lastVisit!) }}
                </p>
                <p class="text-xs text-muted-foreground truncate max-w-40">
                  {{ statsOf(stats, customer.userId).lastServiceName }}
                </p>
              </template>
              <span v-else class="text-xs text-muted-foreground">
                {{ $t("pageFields.customers.neverVisited") }}
              </span>
            </td>
            <td class="px-4 py-3 text-right">
              <Button
                size="sm"
                :variant="customer.userId === selectedId ? 'default' : 'outline'"
                @click.stop="$emit('select', customer.userId)"
              >
                {{ $t("pageFields.customers.viewProfile") }}
              </Button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { ChevronLeft, ChevronRight } from "lucide-vue-next";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { formatPrice } from "@/lib/utils";
import type { IUser } from "@/types/user.type";
import { customerName, formatVisit, initials } from "../customer-format";
import { isNewCustomer, statsOf, type CustomerStats } from "../customer-stats";

defineProps<{
  customers: IUser[];
  stats: Map<string, CustomerStats>;
  total: number;
  page: number;
  pageCount: number;
  loading: boolean;
  selectedId: string | null;
}>();

defineEmits<{
  select: [userId: string];
  page: [page: number];
}>();
</script>
