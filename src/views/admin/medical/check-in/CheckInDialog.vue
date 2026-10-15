<template>
  <AppDialog
    :open="open"
    :title="visit ? $t('medical.checkIn.arriveTitle', { code: visit.code }) : $t('medical.checkIn.title')"
    :description="$t('medical.checkIn.subtitle')"
    :ok-text="okText"
    :ok-disabled="!valid"
    :busy="saving"
    form-id="medical-check-in-form"
    size="lg"
    persistent
    @update:open="emit('update:open', $event)"
  >
    <form id="medical-check-in-form" class="space-y-4" @submit.prevent="submit">
      <div v-if="!visit" class="flex gap-1 rounded-lg border bg-muted/40 p-1">
        <button
          v-for="mode in MODES"
          :key="mode"
          type="button"
          class="flex-1 rounded-md px-3 py-1.5 text-sm font-semibold transition-colors"
          :class="draft.mode === mode ? 'bg-white text-primary shadow-sm' : 'text-muted-foreground'"
          @click="draft.mode = mode"
        >
          {{ $t(`medical.checkIn.mode.${mode}`) }}
        </button>
      </div>

      <section class="space-y-2">
        <Label>{{ $t("medical.checkIn.customer") }}</Label>
        <div v-if="visit" class="rounded-lg border bg-primary/5 px-3 py-2 text-sm">
          <p class="font-semibold">{{ visit.customerName }}</p>
          <p class="text-xs text-muted-foreground">{{ visit.customerPhone }}</p>
        </div>
        <CustomerPanel v-else v-model="buyer" :allow-new="false" />
        <p v-if="needsPets" class="rounded-lg border border-dashed px-3 py-2 text-xs text-muted-foreground">
          {{ $t("medical.checkIn.noPets") }}
          <router-link :to="{ name: 'pets' }" class="font-semibold text-primary underline">{{ $t("medical.checkIn.openPets") }}</router-link>
        </p>
      </section>

      <template v-if="customerId && !needsPets">
        <CheckInFields v-model:draft="draft" :pets="pets" :vets="vets" :pet-locked="!!visit" :pet-name="visit?.petName" />
      </template>
    </form>
  </AppDialog>
</template>

<script lang="ts" setup>
import { computed, toRef } from "vue";
import { useI18n } from "vue-i18n";
import AppDialog from "@/components/common/AppDialog.vue";
import { Label } from "@/components/ui/label";
import type { MedicalVisit } from "@/types/medicalVisit";
import CustomerPanel from "@/views/admin/pos/components/CustomerPanel.vue";
import CheckInFields from "./CheckInFields.vue";
import type { CheckInMode } from "./checkInDraft";
import { useCheckInDraft } from "./useCheckInDraft";

const MODES: CheckInMode[] = ["now", "book"];

const props = defineProps<{
  open: boolean;
  branchId: string;
  /** A booked visit that is arriving; null starts a new one. */
  visit: MedicalVisit | null;
}>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();
const { t } = useI18n();

const { buyer, draft, customerId, pets, needsPets, vets, valid, saving, submit } = useCheckInDraft({
  open: toRef(props, "open"),
  branchId: toRef(props, "branchId"),
  visit: toRef(props, "visit"),
  close: () => emit("update:open", false),
});

const okText = computed(() => (draft.value.mode === "book" && !props.visit ? t("medical.checkIn.book") : t("medical.checkIn.submit")));
</script>
