<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <CalendarDays class="size-4 text-primary" />
      {{ $t("spa.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <SpaNav />
        <div class="flex flex-wrap items-center gap-2">
          <BranchPicker :model-value="branchId" :branches="branches" @update:model-value="selectBranch" />
          <Button v-if="canCreate" :disabled="!branchId" @click="openNew()">
            <Plus class="mr-2 size-4" />
            {{ $t("spa.appointments.new") }}
          </Button>
        </div>
      </div>

      <div class="flex flex-wrap items-center gap-2 rounded-xl border bg-white p-3">
        <Button variant="outline" size="icon" class="size-9" :aria-label="$t('spa.board.prev')" @click="date = addDays(date, -1)">
          <ChevronLeft class="size-4" />
        </Button>
        <Input v-model="date" type="date" class="h-9 w-44" />
        <Button variant="outline" size="icon" class="size-9" :aria-label="$t('spa.board.next')" @click="date = addDays(date, 1)">
          <ChevronRight class="size-4" />
        </Button>
        <Button variant="outline" class="h-9" :disabled="date === todayKey()" @click="date = todayKey()">{{ $t("spa.board.today") }}</Button>
        <p class="text-sm font-semibold">{{ $t(`spa.weekdays.${isoWeekday(date)}`) }}</p>

        <Button v-if="myId" :variant="mine ? 'default' : 'outline'" class="h-9" @click="mine = !mine">
          <UserRound class="mr-2 size-4" />
          {{ $t("spa.detail.mine") }}
        </Button>

        <div class="ml-auto flex rounded-lg border p-0.5">
          <button
            v-for="item in MODES"
            :key="item"
            type="button"
            class="rounded-md px-3 py-1.5 text-xs font-semibold transition-colors"
            :class="mode === item ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:bg-muted'"
            @click="mode = item"
          >
            {{ $t(`spa.board.by.${item}`) }}
          </button>
        </div>
      </div>

      <div class="min-h-[16rem] flex-1 overflow-auto rounded-xl border bg-white">
        <p v-if="boardQuery.isPending.value" class="p-8 text-center text-sm text-muted-foreground">{{ $t("petCare.common.loading") }}</p>
        <p v-else-if="!board || board.isClosed" class="p-8 text-center text-sm text-muted-foreground">{{ $t("spa.board.closed") }}</p>
        <div v-else class="flex min-w-max">
          <div class="sticky left-0 z-20 w-14 shrink-0 border-r bg-white">
            <div class="sticky top-0 z-30 h-10 border-b bg-muted/40" />
            <div v-for="slot in slots" :key="slot" class="relative border-t first:border-t-0" :style="{ height: `${SLOT_PX}px` }">
              <span v-if="slot.endsWith(':00')" class="absolute -top-2 right-2 bg-white px-0.5 text-[10px] text-muted-foreground">{{ slot }}</span>
            </div>
          </div>

          <div v-for="column in columns" :key="column.id ?? 'none'" class="w-48 shrink-0 border-r last:border-r-0">
            <div class="sticky top-0 z-10 flex h-10 items-center justify-center border-b bg-muted/40 px-2 text-xs font-semibold">
              <span class="truncate">{{ column.name }}</span>
            </div>
            <div class="relative">
              <button
                v-for="slot in slots"
                :key="slot"
                type="button"
                class="block w-full border-t border-dashed first:border-t-0"
                :class="canCreate ? 'hover:bg-primary/5' : 'cursor-default'"
                :style="{ height: `${SLOT_PX}px` }"
                :aria-label="`${column.name} ${slot}`"
                :disabled="!canCreate"
                @click="openNew({ time: slot, column })"
              />
              <button
                v-for="item in placed(column)"
                :key="item.ticket.id"
                type="button"
                class="absolute overflow-hidden rounded-md border px-1.5 py-1 text-left text-[11px] leading-tight shadow-sm"
                :class="[TICKET_TONE[item.ticket.status], 'cursor-pointer']"
                :style="{
                  top: `${item.top}px`,
                  height: `${item.height}px`,
                  left: `calc(${(item.lane / item.lanes) * 100}% + 2px)`,
                  width: `calc(${100 / item.lanes}% - 4px)`,
                }"
                :title="`${item.ticket.code} · ${item.ticket.customerName}`"
                @click="openTicket(item.ticket)"
              >
                <span class="block truncate font-semibold">
                  <template v-if="item.ticket.source === 'web'">[{{ $t("spa.source.web") }}] </template>{{ item.ticket.petName ?? item.ticket.customerName }} · {{ item.ticket.name }}
                </span>
                <span class="block truncate opacity-80">{{ timeOf(item.ticket.startAt) }}–{{ timeOf(item.ticket.endAt) }} · {{ item.ticket.customerName }}</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <AppointmentDetailDialog v-model:open="detailOpen" :appointment="detailing" @edit="editFromDetail" />
    <AppointmentDialog v-if="branchId" v-model:open="dialogOpen" :branch-id="branchId" :appointment="editing" :prefill="prefill" />
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { useI18n } from "vue-i18n";
import { CalendarDays, ChevronLeft, ChevronRight, Plus, UserRound } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { useDayBoard, useFindAppointment } from "@/features/admin/schedule/queries/spa";
import { SLOT_MINUTES, type Appointment, type BoardTicket } from "@bongcun/supabase/spa";
import { useAuthStore } from "@/stores";
import { ContentWrap, Header } from "@/features/admin/components";
import BranchPicker from "@/features/admin/pos/components/BranchPicker.vue";
import AppointmentDetailDialog from "../appointments/AppointmentDetailDialog.vue";
import AppointmentDialog, { type BookingPrefill } from "../appointments/AppointmentDialog.vue";
import { addDays, isoWeekday, timeOf, timeSlots, TICKET_TONE, todayKey } from "../format";
import SpaNav from "../SpaNav.vue";
import { placeTickets, SLOT_PX } from "./layout";

type Mode = "staff" | "table";
type Column = { id: string | null; name: string };

const MODES: Mode[] = ["staff", "table"];

const { t } = useI18n();
const auth = useAuthStore();
const canCreate = computed(() => auth.can("schedule", "CREATE"));
const { branches, branchId, selectBranch } = useCurrentBranch();

const date = ref(todayKey());
const mode = ref<Mode>("staff");
const boardQuery = useDayBoard(branchId, date);
const board = computed(() => boardQuery.data.value);

const slots = computed(() => (board.value ? timeSlots(board.value.openTime, board.value.closeTime) : []));

// One column per staff member (or table) plus the tickets nobody was assigned to.
const columns = computed<Column[]>(() => {
  if (!board.value) return [];
  const own = mode.value === "staff" ? board.value.staff : board.value.resources;
  return [...own, { id: null, name: "" }].map((column) => ({
    id: column.id,
    name: column.id ? column.name : t("spa.board.unassigned"),
  }));
});

const columnOf = (ticket: BoardTicket) => (mode.value === "staff" ? ticket.staffId : ticket.resourceId);

// "My tickets" keeps only what is assigned to the signed-in staff member.
const myId = computed(() => auth.session?.user.id);
const mine = ref(false);
const shownTickets = computed(() =>
  (board.value?.tickets ?? []).filter((ticket) => !mine.value || ticket.staffId === myId.value)
);

const placed = (column: Column) =>
  placeTickets(
    shownTickets.value.filter((ticket) => columnOf(ticket) === column.id),
    board.value?.openTime ?? "00:00",
    SLOT_MINUTES
  );

const dialogOpen = ref(false);
const editing = ref<Appointment | null>(null);
const prefill = ref<BookingPrefill>({});

const openNew = (at?: { time: string; column: Column }) => {
  editing.value = null;
  prefill.value = {
    date: date.value,
    time: at?.time,
    staffId: mode.value === "staff" ? (at?.column.id ?? undefined) : undefined,
    resourceId: mode.value === "table" ? (at?.column.id ?? undefined) : undefined,
  };
  dialogOpen.value = true;
};

const detailOpen = ref(false);
const detailing = ref<Appointment | null>(null);

const find = useFindAppointment();
const openTicket = async (ticket: BoardTicket) => {
  if (!branchId.value) return;
  try {
    const appointment = await find.mutateAsync({ branchId: branchId.value, code: ticket.code });
    if (!appointment) return;
    detailing.value = appointment;
    detailOpen.value = true;
  } catch {
    // the mutation already showed the failure toast
  }
};

const editFromDetail = (appointment: Appointment) => {
  detailOpen.value = false;
  editing.value = appointment;
  prefill.value = {};
  dialogOpen.value = true;
};
</script>
