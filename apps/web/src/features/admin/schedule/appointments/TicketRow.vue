<template>
  <li class="flex flex-wrap items-center justify-between gap-3 px-3 py-2.5 text-sm">
    <div :class="ticket.status === 'cancelled' && 'text-muted-foreground line-through'">
      <p class="flex items-center gap-2">
        <PetAvatar v-if="ticket.petName" :name="ticket.petName" :photo-url="ticket.petPhotoUrl" class="size-6 text-[10px]" />
        <span class="font-medium">{{ ticket.petName ?? "—" }}</span>
        · {{ ticket.name }}
      </p>
      <p class="text-xs text-muted-foreground">
        {{ timeOf(ticket.startAt) }} – {{ timeOf(ticket.endAt) }}
        <template v-if="ticket.staffName">· {{ ticket.staffName }}</template>
        <template v-if="ticket.resourceName">· {{ ticket.resourceName }}</template>
        <template v-if="ticket.weightKg">· {{ ticket.weightKg }} kg</template>
      </p>
    </div>
    <div class="flex items-center gap-3">
      <div class="text-right">
        <p class="font-semibold">{{ money(ticket.unitPrice ?? ticket.estPrice) }}</p>
        <p class="text-[10px] uppercase text-muted-foreground">
          {{ ticket.unitPrice !== null ? $t("spa.detail.finalPrice") : $t("spa.detail.estimate") }}
        </p>
      </div>
      <span class="rounded-full px-2 py-0.5 text-[10px] font-semibold" :class="TICKET_BADGE[ticket.status]">
        {{ $t(`spa.ticketStatus.${ticket.status}`) }}
      </span>
      <template v-if="canServe && ticket.status !== 'cancelled'">
        <Button v-if="ticket.status === 'waiting'" size="sm" :disabled="busy" @click="$emit('status', 'in_progress')">
          <Play class="mr-1 size-3.5" />
          {{ $t("spa.detail.start") }}
        </Button>
        <template v-else-if="ticket.status === 'in_progress'">
          <Button size="sm" :disabled="busy" @click="$emit('status', 'done')">
            <Check class="mr-1 size-3.5" />
            {{ $t("spa.detail.finish") }}
          </Button>
          <Button size="sm" variant="ghost" :disabled="busy" :aria-label="$t('spa.detail.undo')" @click="$emit('status', 'waiting')">
            <Undo2 class="size-3.5" />
          </Button>
        </template>
        <Button v-else size="sm" variant="ghost" :disabled="busy" :aria-label="$t('spa.detail.undo')" @click="$emit('status', 'in_progress')">
          <Undo2 class="size-3.5" />
        </Button>
      </template>
    </div>
  </li>
</template>

<script lang="ts" setup>
import PetAvatar from "@/components/common/PetAvatar.vue";
import { Check, Play, Undo2 } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import type { AppointmentTicket, TicketStatus } from "@bongcun/supabase/spa";
import { money } from "@/features/admin/pos/format";
import { timeOf } from "../format";

const TICKET_BADGE: Record<TicketStatus, string> = {
  waiting: "bg-sky-50 text-sky-700",
  in_progress: "bg-violet-50 text-violet-700",
  done: "bg-primary/10 text-primary",
  cancelled: "bg-red-50 text-red-600",
};

defineProps<{ ticket: AppointmentTicket; canServe: boolean; busy: boolean }>();
defineEmits<{ status: [status: TicketStatus] }>();
</script>
