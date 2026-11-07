<template>
  <section class="rounded-xl border bg-white p-4 xl:col-span-2">
    <header class="mb-3 flex flex-wrap items-center justify-between gap-2">
      <div>
        <h2 class="font-semibold">{{ $t("attendance.availability.title") }}</h2>
        <p class="text-sm text-muted-foreground">{{ $t("attendance.availability.hint") }}</p>
      </div>
      <Button type="button" class="min-h-11" @click="open = true">
        <Pencil class="mr-1 size-4" />
        {{ $t("attendance.availability.edit") }}
      </Button>
    </header>
    <p v-if="!items.length" class="text-sm text-muted-foreground">{{ $t("attendance.availability.none") }}</p>
    <AvailabilityWeekView v-else :items="items" />
  </section>
  <AvailabilityDialog v-model:open="open" />
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { Pencil } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { useAvailability } from "@/features/admin/attendance/queries";
import AvailabilityDialog from "../availability/AvailabilityDialog.vue";
import AvailabilityWeekView from "../availability/AvailabilityWeekView.vue";

const query = useAvailability(undefined);
const items = computed(() => query.data.value ?? []);
const open = ref(false);
</script>
