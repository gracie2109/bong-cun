<template>
  <tr class="border-t align-top">
    <td class="px-4 py-3">
      <p class="font-medium">{{ reminder.petName }}</p>
      <p class="text-xs text-muted-foreground">{{ reminder.speciesName }}</p>
    </td>
    <td class="px-4 py-3">
      <p class="font-medium">{{ reminder.customerName }}</p>
      <a :href="`tel:${reminder.customerPhone}`" class="text-xs text-primary underline">{{ reminder.customerPhone }}</a>
    </td>
    <td class="px-4 py-3">{{ reminder.vaccineName ?? "-" }}</td>
    <td class="whitespace-nowrap px-4 py-3">{{ reminder.dueOn }}</td>
    <td class="px-4 py-3 text-xs">
      <template v-if="reminder.remindedAt">
        <p class="font-medium">{{ dateTime(reminder.remindedAt) }}<template v-if="reminder.remindedByName"> · {{ reminder.remindedByName }}</template></p>
        <p v-if="reminder.remindNote" class="text-muted-foreground">{{ reminder.remindNote }}</p>
      </template>
      <span v-else class="text-muted-foreground">-</span>
    </td>
    <td class="whitespace-nowrap px-4 py-3 text-right">
      <div class="flex justify-end gap-2">
        <Button v-if="canMark && reminder.vaccinationId" size="sm" variant="outline" @click="emit('mark')">{{ $t("medical.reminders.mark") }}</Button>
        <Button v-if="reminder.visitId" size="sm" variant="outline" as-child>
          <router-link :to="{ name: 'medicalVisitDetail', params: { visitId: reminder.visitId } }">{{ $t("medical.visits.open") }}</router-link>
        </Button>
      </div>
    </td>
  </tr>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import type { Reminder } from "@bongcun/core/medical";
import { dateTime } from "../format";

defineProps<{ reminder: Reminder; canMark: boolean }>();
const emit = defineEmits<{ mark: [] }>();
</script>
