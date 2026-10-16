<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <CalendarRange class="size-4 text-primary" />
      {{ $t("boarding.timeline.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <BoardingNav />
        <BranchPicker :model-value="branchId" :branches="branches" @update:model-value="selectBranch" />
      </div>

      <div class="flex flex-wrap items-center gap-2 rounded-xl border bg-white p-3">
        <Button variant="outline" size="icon" class="size-9" :aria-label="$t('boarding.timeline.prev')" @click="step(-1)">
          <ChevronLeft class="size-4" />
        </Button>
        <Input v-model="from" type="date" class="h-9 w-44" />
        <Button variant="outline" size="icon" class="size-9" :aria-label="$t('boarding.timeline.next')" @click="step(1)">
          <ChevronRight class="size-4" />
        </Button>
        <Button variant="outline" class="h-9" :disabled="from === today" @click="from = today">{{ $t("boarding.board.today") }}</Button>
        <ul class="ml-auto flex flex-wrap items-center gap-3 text-xs text-muted-foreground">
          <li v-for="status in LEGEND" :key="status" class="flex items-center gap-1.5">
            <span class="size-3 rounded" :class="STAY_TONE[status]" />{{ $t(`boarding.status.${status}`) }}
          </li>
        </ul>
      </div>

      <div class="min-h-[16rem] flex-1 overflow-auto rounded-xl border bg-white">
        <p v-if="query.isPending.value" class="p-8 text-center text-sm text-muted-foreground">{{ $t("petCare.common.loading") }}</p>
        <p v-else-if="groups.length === 0" class="p-8 text-center text-sm text-muted-foreground">{{ $t("boarding.board.empty") }}</p>
        <div v-else class="min-w-[56rem]">
          <div class="sticky top-0 z-20 grid border-b bg-muted/40 text-center text-xs" :style="{ gridTemplateColumns: `${LABEL_WIDTH} minmax(0, 1fr)` }">
            <div class="sticky left-0 border-r bg-muted px-3 py-2 text-left font-semibold">{{ $t("boarding.timeline.kennel") }}</div>
            <div class="grid" :style="{ gridTemplateColumns: `repeat(${TIMELINE_DAYS}, minmax(0, 1fr))` }">
              <div v-for="day in dayKeys" :key="day" class="border-l px-1 py-1.5" :class="day === today && 'bg-primary/10 font-semibold text-primary'">
                <p>{{ day.slice(8) }}/{{ day.slice(5, 7) }}</p>
                <p class="text-[10px] text-muted-foreground">{{ weekday(day) }}</p>
              </div>
            </div>
          </div>
          <section v-for="group in groups" :key="group.id">
            <h2 class="bg-muted/30 px-3 py-1.5 text-xs font-semibold">{{ group.name }} · {{ group.kennels.length }}</h2>
            <TimelineRow
              v-for="kennel in group.kennels"
              :key="kennel.id"
              :kennel="kennel"
              :from="from"
              :days="TIMELINE_DAYS"
              :day-keys="dayKeys"
              :today="today"
            />
          </section>
        </div>
      </div>
    </div>
  </ContentWrap>
</template>

<script lang="ts" setup>
import { useI18n } from "vue-i18n";
import { CalendarRange, ChevronLeft, ChevronRight } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import type { StayStatus } from "@bongcun/core/boarding";
import { ContentWrap, Header } from "@/features/admin/components";
import BranchPicker from "@/features/admin/pos/components/BranchPicker.vue";
import BoardingNav from "../BoardingNav.vue";
import { STAY_TONE } from "../format";
import TimelineRow from "./TimelineRow.vue";
import { TIMELINE_DAYS, useBoardingTimelineView } from "./useBoardingTimeline";
import { LABEL_WIDTH } from "./timelineLayout";

const LEGEND: StayStatus[] = ["booked", "checked_in", "checked_out", "paid"];
const { locale } = useI18n();
const weekday = (day: string): string =>
  new Intl.DateTimeFormat(locale.value, { weekday: "short", timeZone: "UTC" }).format(new Date(`${day}T00:00:00Z`));

const { branches, branchId, selectBranch } = useCurrentBranch();
const { from, query, dayKeys, groups, step, today } = useBoardingTimelineView(branchId);
</script>
