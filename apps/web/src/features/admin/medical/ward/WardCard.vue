<template>
  <article class="space-y-3 rounded-xl border bg-white p-4" :class="row.purpose === 'isolation' && 'border-red-200'">
    <div class="flex flex-wrap items-start justify-between gap-2">
      <div>
        <p class="flex flex-wrap items-center gap-2 font-semibold">
          <PetAvatar :name="row.petName" :photo-url="row.petPhotoUrl" class="size-9 text-xs" />
          {{ row.petName }}
          <span class="rounded-full px-2 py-0.5 text-[10px] font-semibold" :class="row.purpose === 'isolation' ? 'bg-red-100 text-red-800' : 'bg-sky-100 text-sky-800'">
            {{ $t(`medical.ward.purpose.${row.purpose}`) }} · {{ row.kennelCode }}
          </span>
          <span v-if="row.overdue" class="rounded-full bg-red-100 px-2 py-0.5 text-[10px] font-semibold text-red-800">{{ $t("medical.ward.overdue") }}</span>
        </p>
        <p class="text-xs text-muted-foreground">
          {{ row.customerName }} · {{ row.customerPhone }} · {{ $t("medical.ward.since", { time: dateTime(row.since) }) }}
        </p>
      </div>
      <div class="flex flex-wrap gap-2">
        <Button size="sm" variant="outline" as-child>
          <router-link :to="{ name: 'medicalVisitDetail', params: { visitId: row.visitId } }">{{ row.visitCode }}</router-link>
        </Button>
        <template v-if="canUpdate">
          <Button size="sm" variant="outline" @click="emit('order')"><Plus class="mr-1 size-4" />{{ $t("medical.ward.addOrder") }}</Button>
          <Button size="sm" variant="outline" @click="emit('log')"><Activity class="mr-1 size-4" />{{ $t("medical.ward.addLog") }}</Button>
          <Button size="sm" @click="emit('discharge')"><LogOut class="mr-1 size-4" />{{ $t("medical.ward.discharge") }}</Button>
        </template>
      </div>
    </div>

    <p v-if="row.allergies" class="rounded-lg border border-red-300 bg-red-50 px-3 py-1.5 text-sm font-semibold text-red-700">
      {{ $t("medical.flags.allergy") }}: {{ row.allergies }}
    </p>
    <p v-if="row.lastVitals" class="text-xs text-muted-foreground">
      {{ $t("medical.ward.lastVitals") }}: {{ row.lastVitals.content }} ({{ dateTime(row.lastVitals.loggedAt) }})
    </p>

    <p v-if="row.orders.length === 0" class="text-sm text-muted-foreground">{{ $t("medical.ward.noOrders") }}</p>
    <ul v-else class="divide-y rounded-lg border text-sm">
      <li v-for="order in row.orders" :key="order.id" class="space-y-1.5 px-3 py-2">
        <div class="flex items-start justify-between gap-2">
          <p>
            <span class="font-medium">{{ order.name }}</span>
            <span v-if="order.dose" class="text-muted-foreground"> · {{ order.dose }}</span>
            <span v-if="order.kind !== 'care'" class="text-muted-foreground"> × {{ order.qtyPerDose }}</span>
            <span class="text-xs text-muted-foreground"> · {{ order.times.join(", ") }}</span>
          </p>
          <div class="flex shrink-0 items-center gap-1.5">
            <OrderHistoryPopover v-if="order.edited > 0" :order="order" />
            <span v-if="order.missed > 0" class="rounded-full bg-red-100 px-2 py-0.5 text-[10px] font-semibold text-red-800">
              {{ $t("medical.ward.missed", { count: order.missed }) }}
            </span>
            <OrderActions v-if="canUpdate" :order="order" @edit="emit('edit', order)" @replace="emit('replace', order)" @stop="emit('stop', order)" />
          </div>
        </div>
        <div class="flex flex-wrap gap-1.5">
          <template v-for="dose in dosesOf(order.id)" :key="dose.id">
            <span v-if="dose.givenAt" class="rounded-full bg-emerald-100 px-2.5 py-1 text-xs font-semibold text-emerald-800" :title="dose.givenByName ?? ''">
              ✓ {{ timeOf(dose.dueAt) }}
            </span>
            <span v-else-if="dose.skippedReason" class="rounded-full bg-slate-200 px-2.5 py-1 text-xs font-semibold text-slate-700" :title="dose.skippedReason">
              ⊘ {{ timeOf(dose.dueAt) }}
            </span>
            <span v-else class="inline-flex items-center overflow-hidden rounded-full border text-xs font-semibold" :class="isLate(dose) ? 'border-red-300 bg-red-50 text-red-700' : 'bg-white'">
              <span class="px-2.5 py-1">{{ timeOf(dose.dueAt) }}</span>
              <template v-if="canUpdate">
                <button type="button" class="border-l px-2 py-1 hover:bg-emerald-50" :aria-label="$t('medical.ward.give')" @click="emit('give', dose)"><Check class="size-3.5" /></button>
                <button type="button" class="border-l px-2 py-1 hover:bg-slate-100" :aria-label="$t('medical.ward.skip')" @click="emit('skip', dose)"><Ban class="size-3.5" /></button>
              </template>
            </span>
          </template>
        </div>
      </li>
    </ul>
  </article>
</template>

<script lang="ts" setup>
import PetAvatar from "@/components/common/PetAvatar.vue";
import { Activity, Ban, Check, LogOut, Plus } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import type { WardDose, WardOrder, WardRow } from "@bongcun/core/medical";
import { timeOf } from "@/features/admin/schedule/format";
import { dateTime } from "../format";
import OrderActions from "./OrderActions.vue";
import OrderHistoryPopover from "./OrderHistoryPopover.vue";

const props = defineProps<{ row: WardRow; canUpdate: boolean }>();
const emit = defineEmits<{
  order: [];
  log: [];
  discharge: [];
  edit: [order: WardOrder];
  replace: [order: WardOrder];
  stop: [order: WardOrder];
  give: [dose: WardDose];
  skip: [dose: WardDose];
}>();

const dosesOf = (orderId: string) => props.row.doses.filter((dose) => dose.orderId === orderId);
const isLate = (dose: WardDose) => new Date(dose.dueAt).getTime() < Date.now();
</script>
