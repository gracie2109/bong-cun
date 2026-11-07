<template>
  <td class="min-w-40 border-l p-1.5 align-top" :class="[isToday && 'bg-primary/5', past && 'bg-muted/40']">
    <div class="flex min-h-11 flex-wrap content-start items-start gap-1">
      <button
        v-for="entry in shown"
        :key="entry.assignment.id"
        type="button"
        class="max-w-full truncate rounded-md border px-1.5 py-0.5 text-xs font-semibold"
        :class="[SHIFT_COLOR_CLASS[color].chip, past && 'opacity-70']"
        :disabled="!canOpen"
        :title="entry.assignment.note ?? undefined"
        @click="emit('edit', entry.staff, entry.assignment)"
      >
        {{ entry.staff.name }}
      </button>

      <Popover v-if="hidden.length">
        <PopoverTrigger as-child>
          <button type="button" class="rounded-md border border-dashed px-1.5 py-0.5 text-xs font-semibold text-muted-foreground hover:bg-muted">
            {{ $t("attendance.roster.more", { n: hidden.length }) }}
          </button>
        </PopoverTrigger>
        <PopoverContent class="max-h-64 w-56 space-y-1 overflow-y-auto p-2" align="start">
          <button
            v-for="entry in entries"
            :key="entry.assignment.id"
            type="button"
            class="block w-full truncate rounded-md px-2 py-1 text-left text-sm hover:bg-muted"
            :disabled="!canOpen"
            @click="emit('edit', entry.staff, entry.assignment)"
          >
            {{ entry.staff.name }}
          </button>
        </PopoverContent>
      </Popover>

      <Popover v-if="canCreate" v-model:open="pickerOpen">
        <PopoverTrigger as-child>
          <button type="button" class="flex size-6 items-center justify-center rounded-md text-muted-foreground/60 hover:bg-muted hover:text-foreground" :aria-label="$t('attendance.roster.addShift')">
            <Plus class="size-4" />
          </button>
        </PopoverTrigger>
        <PopoverContent class="w-60 space-y-2 p-2" align="start">
          <Input v-model="search" class="h-9" :placeholder="$t('attendance.roster.searchStaff')" />
          <ul class="max-h-56 space-y-0.5 overflow-y-auto">
            <li v-for="person in candidates" :key="person.userId">
              <button type="button" class="block w-full truncate rounded-md px-2 py-1.5 text-left text-sm hover:bg-muted" @click="pick(person)">
                {{ person.name }}
              </button>
            </li>
            <li v-if="!candidates.length" class="px-2 py-2 text-sm text-muted-foreground">{{ $t("attendance.roster.noOneToAdd") }}</li>
          </ul>
        </PopoverContent>
      </Popover>
    </div>
  </td>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { Plus } from "lucide-vue-next";
import { Input } from "@/components/ui/input";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { SHIFT_COLOR_CLASS } from "@/features/admin/attendance/shared/shiftColors";
import type { RosterAssignment, RosterStaff, ShiftColor } from "@bongcun/core/attendance";
import type { ShiftBoardEntry } from "./shiftBoard";

/** Past this many names the cell shows "+N" and keeps the rest in a list, so a busy shift stays one tidy block. */
const SHOWN = 4;

const props = defineProps<{
  entries: ShiftBoardEntry[];
  color: ShiftColor;
  isToday: boolean;
  past: boolean;
  canCreate: boolean;
  canOpen: boolean;
  /** Everyone of the branch, to pick from when adding. */
  staff: RosterStaff[];
}>();
const emit = defineEmits<{ edit: [staff: RosterStaff, assignment: RosterAssignment]; add: [staff: RosterStaff] }>();

const search = ref("");
const pickerOpen = ref(false);
const shown = computed(() => props.entries.slice(0, SHOWN));
const hidden = computed(() => props.entries.slice(SHOWN));
/** Already in this very cell: offering them again would only fail as a duplicate. */
const onShift = computed(() => new Set(props.entries.map((entry) => entry.staff.userId)));
const candidates = computed(() => {
  const term = search.value.trim().toLowerCase();
  return props.staff.filter((person) => !onShift.value.has(person.userId) && (!term || person.name.toLowerCase().includes(term)));
});

const pick = (person: RosterStaff) => {
  pickerOpen.value = false;
  search.value = "";
  emit("add", person);
};
</script>
