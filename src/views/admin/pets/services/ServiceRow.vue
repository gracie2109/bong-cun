<template>
  <tr class="border-t" :class="service.isActive ? '' : 'opacity-60'">
    <td class="px-4 py-3">
      <p class="flex items-center gap-2 font-semibold">
        {{ service.name }}
        <span
          v-if="!service.isActive"
          class="rounded-full bg-muted px-2 py-0.5 text-[10px] font-semibold text-muted-foreground"
        >
          {{ $t("petCare.common.archived") }}
        </span>
      </p>
      <p v-if="service.desc" class="line-clamp-1 text-xs text-muted-foreground">{{ service.desc }}</p>
    </td>
    <td class="px-4 py-3">
      <div class="flex flex-wrap gap-1">
        <span
          v-for="item in service.species"
          :key="item.id"
          class="rounded-full bg-primary/10 px-2 py-0.5 text-[11px] font-medium text-primary"
        >
          {{ item.name }}
        </span>
      </div>
    </td>
    <td class="px-4 py-3">
      <template v-if="service.type === 'all'">
        <p class="font-medium">{{ formatPrice(service.generalPrice ?? 0) }}</p>
        <p class="text-xs text-muted-foreground">{{ $t("petCare.services.typeAll") }}</p>
      </template>
      <template v-else>
        <p class="text-xs text-muted-foreground">{{ $t("petCare.services.typeByWeight") }}</p>
        <router-link
          class="text-xs font-semibold text-primary hover:underline"
          :to="{ name: 'petPrices', query: { speciesId: service.speciesIds[0], serviceId: service.id } }"
        >
          {{ $t("petCare.services.setPrices") }}
        </router-link>
      </template>
    </td>
    <td class="whitespace-nowrap px-4 py-3">
      {{ $t("petCare.services.minutes", { n: service.duration[0] }) }}
    </td>
    <td class="px-4 py-3 text-right">
      <DropdownMenu v-if="canUpdate">
        <DropdownMenuTrigger as-child>
          <Button variant="ghost" size="icon" class="size-8">
            <EllipsisVertical class="size-4" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem @click="emit('edit', service)">{{ $t("petCare.common.edit") }}</DropdownMenuItem>
          <DropdownMenuItem v-if="service.isActive" @click="emit('archive', service)">
            {{ $t("petCare.common.archive") }}
          </DropdownMenuItem>
          <DropdownMenuItem v-else @click="emit('restore', service)">
            {{ $t("petCare.common.restore") }}
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </td>
  </tr>
</template>

<script lang="ts" setup>
import { EllipsisVertical } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { formatPrice } from "@/lib/utils";
import type { PetService } from "@/repositories/petServices";

defineProps<{ service: PetService; canUpdate: boolean }>();

const emit = defineEmits<{
  edit: [service: PetService];
  archive: [service: PetService];
  restore: [service: PetService];
}>();
</script>
