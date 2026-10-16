<template>
  <section v-if="tickets.length" class="space-y-2 rounded-lg border border-primary/30 bg-primary/5 p-2.5">
    <div class="flex items-center justify-between gap-2">
      <p class="text-xs font-semibold text-primary">{{ $t("pos.spaTickets.title", { count: tickets.length }) }}</p>
      <Button size="sm" variant="outline" class="h-7 text-xs" :disabled="!pending.length" @click="pending.forEach((ticket) => emit('add', ticket))">
        {{ $t("pos.spaTickets.addAll") }}
      </Button>
    </div>
    <ul class="space-y-1">
      <li v-for="ticket in tickets" :key="ticket.id" class="flex items-center justify-between gap-2 text-xs">
        <span class="flex min-w-0 items-center gap-1.5 truncate">
          <PetAvatar v-if="ticket.petName" :name="ticket.petName" :photo-url="ticket.petPhotoUrl" class="size-5 shrink-0 text-[9px]" />
          <span class="font-medium">{{ ticket.petName ?? "—" }}</span>
          · {{ ticket.name }}
          <span class="text-muted-foreground">· {{ ticket.code }}</span>
        </span>
        <span class="flex items-center gap-2">
          <span class="font-semibold">{{ money(ticket.unitPrice) }}</span>
          <Button size="sm" variant="ghost" class="h-7 px-2 text-xs" :disabled="added.has(ticket.id)" @click="emit('add', ticket)">
            {{ added.has(ticket.id) ? $t("pos.spaTickets.added") : $t("pos.spaTickets.add") }}
          </Button>
        </span>
      </li>
    </ul>
  </section>
</template>

<script lang="ts" setup>
import PetAvatar from "@/components/common/PetAvatar.vue";
import { computed } from "vue";
import { Button } from "@/components/ui/button";
import { useBillableTickets } from "@/queries/spa";
import type { BillableTicket } from "@bongcun/supabase/spa";
import { money } from "../format";

const props = defineProps<{
  branchId: string | undefined;
  customerId: string | undefined;
  /** Ids of the tickets already in the cart. */
  added: Set<string>;
}>();
const emit = defineEmits<{ add: [ticket: BillableTicket] }>();

const ticketsQuery = useBillableTickets(
  computed(() => props.branchId),
  computed(() => props.customerId)
);
const tickets = computed(() => ticketsQuery.data.value ?? []);
const pending = computed(() => tickets.value.filter((ticket) => !props.added.has(ticket.id)));
</script>
