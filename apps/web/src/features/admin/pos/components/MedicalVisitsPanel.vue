<template>
  <section v-if="visits.length" class="space-y-2 rounded-lg border border-primary/30 bg-primary/5 p-2.5">
    <p class="text-xs font-semibold text-primary">{{ $t("pos.medicalVisits.title", { count: visits.length }) }}</p>
    <ul class="space-y-1">
      <li v-for="visit in visits" :key="visit.visitId" class="flex items-center justify-between gap-2 text-xs">
        <span class="flex min-w-0 items-center gap-1.5 truncate">
          <PetAvatar :name="visit.petName" :photo-url="visit.petPhotoUrl" class="size-5 shrink-0 text-[9px]" />
          <span class="font-medium">{{ visit.code }}</span>
          <span class="text-muted-foreground">· {{ visit.petName }} · {{ $t("pos.medicalVisits.lines", { count: visit.items.length }) }}</span>
        </span>
        <span class="flex items-center gap-2">
          <span class="font-semibold">{{ money(visit.total) }}</span>
          <Button size="sm" variant="ghost" class="h-7 px-2 text-xs" :disabled="isAdded(visit)" @click="emit('add', visit)">
            {{ isAdded(visit) ? $t("pos.medicalVisits.added") : $t("pos.medicalVisits.add") }}
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
import { useBillableMedical } from "@/features/admin/pos/queries/medicalBilling";
import type { BillableVisit } from "@bongcun/core/medical";
import { money } from "../format";

const props = defineProps<{
  branchId: string | undefined;
  customerId: string | undefined;
  /** Ids of the visit lines already in the cart. */
  added: Set<string>;
}>();
const emit = defineEmits<{ add: [visit: BillableVisit] }>();

const visitsQuery = useBillableMedical(
  computed(() => props.branchId),
  computed(() => props.customerId)
);
const visits = computed(() => visitsQuery.data.value ?? []);

const isAdded = (visit: BillableVisit) => visit.items.every((item) => props.added.has(item.id));
</script>
