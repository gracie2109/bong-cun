<template>
  <article
    class="cursor-pointer space-y-2 rounded-xl border bg-white p-3 shadow-sm transition-colors hover:border-primary/50"
    :class="[visit.priority === 'urgent' && 'border-red-300 bg-red-50/40', visit.status === 'scheduled' && 'opacity-70']"
    @click="emit('open')"
  >
    <div class="flex items-start justify-between gap-2">
      <div class="min-w-0">
        <p class="flex items-center gap-2 truncate font-semibold">
          <PetAvatar :name="visit.petName" :photo-url="visit.petPhotoUrl" class="size-7 shrink-0 text-[10px]" />
          <span v-if="visit.queueNo" class="mr-1 text-primary">#{{ visit.queueNo }}</span>{{ visit.petName }}
          <span v-if="visit.speciesName" class="text-xs font-normal text-muted-foreground">· {{ visit.speciesName }}</span>
        </p>
        <p class="truncate text-xs text-muted-foreground">{{ visit.customerName }} · {{ visit.customerPhone }}</p>
      </div>
      <span v-if="visit.priority === 'urgent'" class="shrink-0 rounded-full bg-red-600 px-2 py-0.5 text-[10px] font-semibold text-white">
        {{ $t("medical.priority.urgent") }}
      </span>
    </div>

    <p v-if="visit.reason" class="line-clamp-2 text-sm">{{ visit.reason }}</p>

    <div class="flex flex-wrap gap-1">
      <span v-if="visit.hasAllergy" class="rounded-full bg-red-100 px-2 py-0.5 text-[10px] font-semibold text-red-700">{{ $t("medical.flags.allergy") }}</span>
      <span v-if="visit.hasBehavior" class="rounded-full bg-amber-100 px-2 py-0.5 text-[10px] font-semibold text-amber-800">{{ $t("medical.flags.behavior") }}</span>
      <span v-if="visit.contagious" class="rounded-full bg-fuchsia-100 px-2 py-0.5 text-[10px] font-semibold text-fuchsia-800">{{ $t("medical.flags.contagious") }}</span>
    </div>

    <div class="flex items-center justify-between gap-2 text-xs text-muted-foreground">
      <span>{{ meta }}</span>
      <div class="flex gap-1" @click.stop>
        <Button v-if="canStart" size="sm" @click="emit('start')">{{ $t("medical.queue.takeCase") }}</Button>
        <Button v-if="canCheckIn" size="sm" variant="outline" @click="emit('check-in')">{{ $t("medical.queue.checkIn") }}</Button>
        <Button v-if="canNoShow" size="sm" variant="ghost" @click="emit('no-show')">{{ $t("medical.queue.noShow") }}</Button>
      </div>
    </div>
  </article>
</template>

<script lang="ts" setup>
import PetAvatar from "@/components/common/PetAvatar.vue";
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import { Button } from "@/components/ui/button";
import type { MedicalVisit } from "@bongcun/core/medical";
import { minutesSince, timeOf } from "../format";

const props = defineProps<{ visit: MedicalVisit; canStart: boolean; canCheckIn: boolean; canNoShow: boolean }>();
const emit = defineEmits<{ open: []; start: []; "check-in": []; "no-show": [] }>();
const { t } = useI18n();

// Waiting shows how long; a booked visit shows its hour; the vet is named once the case is taken.
const meta = computed(() => {
  const { visit } = props;
  if (visit.status === "scheduled") return t("medical.queue.bookedAt", { time: visit.scheduledAt ? timeOf(visit.scheduledAt) : "" });
  const vet = visit.vetName ? ` · ${visit.vetName}` : "";
  if (visit.status === "waiting") return t("medical.queue.waited", { minutes: minutesSince(visit.checkedInAt) }) + vet;
  return (visit.vetName ?? t("medical.queue.noVet")) + (visit.outcome ? ` · ${t(`medical.outcome.${visit.outcome}`)}` : "");
});
</script>
