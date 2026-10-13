<template>
  <tr class="border-t align-top">
    <td class="whitespace-nowrap px-4 py-3">
      <p class="font-semibold">{{ appointment.code }}</p>
      <span class="mt-1 inline-block rounded-full px-2 py-0.5 text-[10px] font-semibold" :class="APPOINTMENT_TONE[appointment.status]">
        {{ $t(`spa.status.${appointment.status}`) }}
      </span>
    </td>
    <td class="whitespace-nowrap px-4 py-3">
      <p>{{ dateTime(appointment.startAt) }}</p>
      <p class="text-xs text-muted-foreground">→ {{ timeOf(appointment.endAt) }}</p>
    </td>
    <td class="px-4 py-3">
      <p class="font-medium">{{ appointment.customerName }}</p>
      <p class="text-xs text-muted-foreground">{{ appointment.customerPhone }}</p>
    </td>
    <td class="px-4 py-3">
      <ul class="space-y-1">
        <li v-for="ticket in appointment.tickets" :key="ticket.id" :class="ticket.status === 'cancelled' && 'text-muted-foreground line-through'">
          <span class="font-medium">{{ ticket.petName ?? "—" }}</span>
          · {{ ticket.name }}
          <span class="text-xs text-muted-foreground">
            · {{ timeOf(ticket.startAt) }}
            <template v-if="ticket.staffName">· {{ ticket.staffName }}</template>
            <template v-if="ticket.resourceName">· {{ ticket.resourceName }}</template>
          </span>
        </li>
      </ul>
    </td>
    <td class="whitespace-nowrap px-4 py-3 text-right">
      <div class="flex justify-end gap-2">
        <Button size="sm" variant="outline" @click="emit('open')">{{ $t("spa.detail.open") }}</Button>
        <Button v-if="canEdit" size="sm" variant="outline" @click="emit('edit')">{{ $t("petCare.common.edit") }}</Button>
      </div>
    </td>
  </tr>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import type { Appointment } from "@/repositories/spa";
import { APPOINTMENT_TONE, dateTime, timeOf } from "../format";

defineProps<{ appointment: Appointment; canEdit: boolean }>();

const emit = defineEmits<{ edit: []; open: [] }>();
</script>
