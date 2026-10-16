<template>
  <aside class="rounded-xl border bg-white p-5 xl:sticky xl:top-16 self-start">
    <p v-if="!customer" class="py-16 text-center text-sm text-muted-foreground">
      {{ $t("pageFields.customers.detail.placeholder") }}
    </p>

    <template v-else>
      <div class="flex items-start gap-3">
        <Avatar class="size-14">
          <AvatarImage v-if="customer.photoURL" :src="customer.photoURL" />
          <AvatarFallback class="bg-primary/15 text-primary text-lg font-semibold">
            {{ initials(customer) }}
          </AvatarFallback>
        </Avatar>
        <div class="min-w-0">
          <h2 class="text-lg font-bold leading-tight break-words">{{ customerName(customer) }}</h2>
          <p class="text-xs text-muted-foreground">
            {{ $t("pageFields.customers.detail.code") }}: #{{ customerCode(customer) }} •
            {{ membership }}
          </p>
          <p class="mt-1 flex items-center gap-1.5 text-sm">
            <Phone class="size-3.5 text-primary" />
            {{ customer.phoneNumber || $t("pageFields.customers.detail.noPhone") }}
          </p>
        </div>
      </div>

      <div class="mt-4 space-y-2 rounded-lg bg-muted/50 p-3 text-sm">
        <p class="flex items-start gap-2">
          <MapPin class="size-4 mt-0.5 shrink-0 text-primary" />
          <span>{{ address || $t("pageFields.customers.detail.noAddress") }}</span>
        </p>
        <p class="flex items-start gap-2 break-all">
          <Mail class="size-4 mt-0.5 shrink-0 text-primary" />
          <span>{{ customer.email }}</span>
        </p>
      </div>

      <section class="mt-5">
        <h3 class="mb-2 text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">
          {{ $t("pageFields.customers.detail.pets") }}
        </h3>
        <p class="rounded-lg border border-dashed p-3 text-center text-xs text-muted-foreground">
          {{ $t("pageFields.customers.detail.petsEmpty") }}
        </p>
      </section>

      <section class="mt-5">
        <div class="mb-2 flex items-center justify-between">
          <h3 class="text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">
            {{ $t("pageFields.customers.detail.history") }}
          </h3>
          <span v-if="orders.length" class="text-xs text-primary">
            {{ $t("pageFields.customers.detail.historyCount", { n: stats.serviceCount }) }}
          </span>
        </div>

        <p
          v-if="orders.length === 0"
          class="rounded-lg border border-dashed p-3 text-center text-xs text-muted-foreground"
        >
          {{ $t("pageFields.customers.detail.historyEmpty") }}
        </p>
        <ul v-else class="space-y-2">
          <li v-for="order in recent" :key="order.id" class="rounded-lg bg-muted/50 p-3">
            <div class="flex items-start justify-between gap-3">
              <div class="min-w-0">
                <p class="font-semibold text-sm">{{ lineNames(order) }}</p>
                <p class="text-xs text-muted-foreground">{{ formatVisit(visitDate(order)) }}</p>
              </div>
              <span class="shrink-0 text-sm font-bold">{{ formatPrice(orderTotal(order)) }}</span>
            </div>
          </li>
        </ul>
      </section>
    </template>
  </aside>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import { Mail, MapPin, Phone } from "lucide-vue-next";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { formatPrice } from "@/lib/utils";
import type { CustomerOrder } from "@/repositories/orders";
import type { IUser } from "@/types/user.type";
import {
  customerCode,
  customerName,
  formatAddress,
  formatVisit,
  initials,
  monthsSince,
} from "../customer-format";
import {
  RECENT_HISTORY_LIMIT,
  activeLines,
  orderTotal,
  visitDate,
  type CustomerStats,
} from "../customer-stats";

const props = defineProps<{
  customer: IUser | null;
  orders: CustomerOrder[];
  stats: CustomerStats;
}>();

const { t } = useI18n();

const address = computed(() => (props.customer ? formatAddress(props.customer) : ""));

const membership = computed(() => {
  const months = monthsSince(props.customer?.createdAt);
  return months > 0
    ? t("pageFields.customers.detail.memberFor", { n: months })
    : t("pageFields.customers.detail.memberNew");
});

// Orders whose lines were all cancelled are not part of the visible history.
const recent = computed(() =>
  props.orders.filter((order) => activeLines(order).length > 0).slice(0, RECENT_HISTORY_LIMIT)
);

const lineNames = (order: CustomerOrder) =>
  activeLines(order)
    .map((line) => line.name)
    .join(" + ");
</script>
