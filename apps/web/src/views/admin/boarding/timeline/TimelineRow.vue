<template>
  <div class="grid border-t" :style="{ gridTemplateColumns: `${LABEL_WIDTH} minmax(0, 1fr)` }">
    <div class="sticky left-0 z-10 flex flex-col justify-center border-r bg-white px-3 py-2">
      <span class="text-sm font-semibold">{{ kennel.code }}</span>
      <span v-if="kennel.status !== 'ready'" class="text-[11px] text-muted-foreground">{{ $t(`boarding.kennelStatus.${kennel.status}`) }}</span>
    </div>
    <div
      class="relative grid gap-y-1 py-1.5"
      :style="{ gridTemplateColumns: `repeat(${days}, minmax(0, 1fr))`, gridTemplateRows: `repeat(${lanes}, 1.75rem)` }"
    >
      <span
        v-for="(day, index) in dayKeys"
        :key="day"
        class="pointer-events-none absolute inset-y-0 border-l"
        :class="day === today ? 'border-primary/40 bg-primary/5' : 'border-border/60'"
        :style="{ left: `${(index / days) * 100}%`, width: `${100 / days}%` }"
      />
      <router-link
        v-for="item in placed"
        :key="item.segment.stayPetId"
        :to="{ name: 'boardingStayDetail', params: { stayId: item.segment.stayId } }"
        class="relative z-[1] mx-0.5 truncate rounded-md px-2 text-xs font-medium leading-7"
        :class="[STAY_TONE[item.segment.stayStatus], item.cutLeft && 'rounded-l-none', item.cutRight && 'rounded-r-none']"
        :style="{ gridColumn: `${item.start} / ${item.end}`, gridRow: item.lane }"
        :title="`${item.segment.petName} · ${item.segment.customerName} · ${item.segment.stayCode}`"
      >
        {{ item.segment.petName }}
      </router-link>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import type { TimelineKennel } from "@/types/boarding";
import { STAY_TONE } from "../format";
import { LABEL_WIDTH, laneCount, placeSegments } from "./timelineLayout";

const props = defineProps<{ kennel: TimelineKennel; from: string; days: number; dayKeys: string[]; today: string }>();

const placed = computed(() => placeSegments(props.kennel.segments, props.from, props.days));
const lanes = computed(() => laneCount(placed.value));
</script>
