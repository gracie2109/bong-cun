<template>
  <AppDialog
    :open="open"
    :title="stay ? $t('boarding.dialog.editTitle', { code: stay.code }) : $t('boarding.dialog.newTitle')"
    :description="$t('boarding.dialog.subtitle')"
    :ok-text="stay ? $t('petCare.common.save') : $t('boarding.dialog.book')"
    :ok-disabled="!valid"
    :busy="saving"
    form-id="boarding-stay-form"
    size="xl"
    persistent
    @update:open="emit('update:open', $event)"
  >
    <form id="boarding-stay-form" class="space-y-5" @submit.prevent="submit">
      <section class="space-y-2">
        <Label>{{ $t("boarding.dialog.customer") }}</Label>
        <div v-if="stay" class="rounded-lg border bg-primary/5 px-3 py-2 text-sm">
          <p class="font-semibold">{{ stay.customerName }}</p>
          <p class="text-xs text-muted-foreground">{{ stay.customerPhone }}</p>
        </div>
        <CustomerPanel v-else v-model="buyer" :allow-new="false" />
        <p v-if="needsPets" class="rounded-lg border border-dashed px-3 py-2 text-xs text-muted-foreground">
          {{ $t("boarding.dialog.noPets") }}
          <router-link :to="{ name: 'pets' }" class="font-semibold text-primary underline">{{ $t("boarding.dialog.openPets") }}</router-link>
        </p>
      </section>

      <template v-if="customerId && !needsPets">
        <StayDates v-model:draft="draft" :rules="rules" />

        <section class="space-y-3">
          <StayPetFields
            v-for="(pet, index) in draft.pets"
            :key="pet.key"
            :pet="pet"
            :index="index"
            :removable="draft.pets.length > 1"
            :branch-id="branchId"
            :pets="pets"
            :types="types"
            :availability="availability"
            :siblings="draft.pets"
            @remove="removePet(index)"
          />
          <Button type="button" variant="outline" size="sm" @click="addPet">
            <Plus class="mr-1 size-4" />
            {{ $t("boarding.dialog.addPet") }}
          </Button>
        </section>

        <StayQuoteCard :quote="quote" :quoting="quoting" :error="quoteError" />

        <section class="grid gap-3 sm:grid-cols-2">
          <div class="space-y-1.5">
            <Label for="boarding-emergency">{{ $t("boarding.dialog.emergencyPhone") }}</Label>
            <Input id="boarding-emergency" v-model="draft.emergencyPhone" inputmode="tel" />
          </div>
          <div class="space-y-1.5">
            <Label for="boarding-note">{{ $t("boarding.dialog.note") }}</Label>
            <Textarea id="boarding-note" v-model="draft.note" rows="2" :placeholder="$t('boarding.dialog.notePlaceholder')" />
          </div>
        </section>
      </template>
    </form>

    <template v-if="stay && canCancel" #footer="{ cancel, busy }">
      <Button type="button" variant="outline" class="mr-auto text-red-600" :disabled="busy" @click="confirmCancel = true">
        {{ $t("boarding.dialog.cancelStay") }}
      </Button>
      <Button type="button" variant="outline" :disabled="busy" @click="cancel">{{ $t("petCare.common.cancel") }}</Button>
      <Button type="submit" form="boarding-stay-form" data-dialog-ok :disabled="!valid || busy">
        <Loader2 v-if="busy" class="mr-2 size-4 animate-spin" />
        {{ $t("petCare.common.save") }}
      </Button>
    </template>
  </AppDialog>

  <ConfirmDialog
    :open="confirmCancel"
    :title="$t('boarding.dialog.cancelTitle', { code: stay?.code ?? '' })"
    :desc="$t('boarding.dialog.cancelDesc')"
    :ok-btn="$t('boarding.dialog.cancelStay')"
    :cancel-btn="$t('boarding.dialog.keep')"
    danger
    @open-change="confirmCancel = false"
    @handle-ok="cancelStay"
  />
</template>

<script lang="ts" setup>
import { computed, toRef } from "vue";
import { Loader2, Plus } from "lucide-vue-next";
import AppDialog from "@/components/common/AppDialog.vue";
import ConfirmDialog from "@/components/common/ConfirmDialog.vue";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { useAuthStore } from "@/stores";
import type { BoardingStay } from "@bongcun/core/boarding";
import CustomerPanel from "@/views/admin/pos/components/CustomerPanel.vue";
import StayDates from "./StayDates.vue";
import StayPetFields from "./StayPetFields.vue";
import StayQuoteCard from "./StayQuoteCard.vue";
import type { StayPrefill } from "./stayDraft";
import { useStayDraft } from "./useStayDraft";

const props = defineProps<{
  open: boolean;
  branchId: string;
  /** The booked stay being edited; null books a new one. */
  stay: BoardingStay | null;
  prefill?: StayPrefill;
}>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const auth = useAuthStore();
const canCancel = computed(() => auth.can("boarding", "DELETE"));

const {
  buyer, draft, confirmCancel, customerId, pets, needsPets, types, availability, rules,
  quote, quoting, quoteError, valid, saving, addPet, removePet, submit, cancelStay,
} = useStayDraft({
  open: toRef(props, "open"),
  branchId: toRef(props, "branchId"),
  stay: toRef(props, "stay"),
  prefill: toRef(props, "prefill"),
  close: () => emit("update:open", false),
});
</script>
