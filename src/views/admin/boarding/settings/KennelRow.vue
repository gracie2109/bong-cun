<template>
  <tr class="border-t" :class="!kennel.isActive && 'text-muted-foreground'">
    <td class="whitespace-nowrap px-4 py-3">
      <p class="font-semibold">{{ kennel.code }}</p>
      <p v-if="kennel.name" class="text-xs text-muted-foreground">{{ kennel.name }}</p>
    </td>
    <td class="px-4 py-3">{{ kennel.kennelTypeName }}</td>
    <td class="px-4 py-3">
      <span class="rounded-full px-2 py-0.5 text-[10px] font-semibold" :class="KENNEL_STATUS_TONE[kennel.status]">
        {{ $t(`boarding.kennelStatus.${kennel.status}`) }}
      </span>
      <span v-if="!kennel.isActive" class="ml-1 rounded bg-slate-200 px-1.5 py-0.5 text-[10px] font-semibold text-slate-700">
        {{ $t("boarding.common.inactive") }}
      </span>
    </td>
    <td class="whitespace-nowrap px-4 py-3 text-right">
      <div class="flex justify-end gap-2">
        <Button v-if="canUpdate && kennel.status === 'cleaning'" size="sm" variant="outline" @click="emit('status', 'ready')">
          {{ $t("boarding.kennels.markClean") }}
        </Button>
        <Button v-if="canUpdate && kennel.status === 'ready'" size="sm" variant="ghost" @click="emit('status', 'maintenance')">
          {{ $t("boarding.kennels.markMaintenance") }}
        </Button>
        <Button v-if="canUpdate && kennel.status === 'maintenance'" size="sm" variant="outline" @click="emit('status', 'ready')">
          {{ $t("boarding.kennels.markReady") }}
        </Button>
        <Button v-if="canEdit" size="sm" variant="outline" @click="emit('edit')">{{ $t("petCare.common.edit") }}</Button>
      </div>
    </td>
  </tr>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import type { Kennel, KennelStatus } from "@/types/boarding";
import { KENNEL_STATUS_TONE } from "../format";

defineProps<{ kennel: Kennel; canEdit: boolean; canUpdate: boolean }>();
const emit = defineEmits<{ edit: []; status: [status: KennelStatus] }>();
</script>
