<template>
  <section class="shop-container max-w-[880px] space-y-6 pb-16 pt-6 md:pt-10">
    <header>
      <p class="shop-eyebrow !text-sage">{{ $t("client.spa.eyebrow") }}</p>
      <h1 class="shop-display mt-1 text-3xl md:text-4xl">{{ $t("client.booking.title") }}</h1>
    </header>

    <div v-if="wizard.loading.value" class="space-y-4" aria-hidden="true">
      <div class="shop-skeleton h-8 w-72 rounded-full" />
      <div class="shop-skeleton h-64 rounded-3xl" />
    </div>

    <BookingDone v-else-if="wizard.result.value" :code="wizard.result.value.code" />

    <EmptyState v-else-if="!wizard.hasCustomer.value" :title="$t('client.booking.needProfile')">
      <Button as-child class="h-11 rounded-full px-6">
        <RouterLink :to="{ name: 'account-profile' }">{{ $t("client.pets.goProfile") }}</RouterLink>
      </Button>
    </EmptyState>
    <EmptyState v-else-if="wizard.pets.value.length === 0" :title="$t('client.booking.needPet')" :text="$t('client.booking.needPetHint')" />

    <div v-else class="space-y-6 rounded-3xl border bg-white p-5 sm:p-8">
      <BookingSteps :steps="wizard.steps.value" :current="wizard.stepIndex.value" />

      <StepBranch
        v-if="wizard.current.value === 'branch'"
        :branches="wizard.branches.value"
        :selected="wizard.branchId.value"
        @pick="wizard.pickBranch"
      />
      <StepPets
        v-else-if="wizard.current.value === 'pets'"
        :pets="wizard.pets.value"
        :catalog="wizard.catalog.value"
        :picks="wizard.picks.value"
        @toggle="wizard.toggle"
      />
      <StepSlot
        v-else-if="wizard.current.value === 'slot'"
        v-model:date="wizard.date.value"
        :slots="wizard.slots.value"
        :loading="wizard.slotsLoading.value"
        :selected="wizard.startAt.value"
        :total-minutes="wizard.quote.value?.totalMinutes ?? 0"
        :rules="wizard.rules.value"
        @pick="wizard.startAt.value = $event"
      />
      <StepConfirm
        v-else-if="wizard.quote.value && wizard.startAt.value"
        v-model:note="wizard.note.value"
        :branch-name="branchName"
        :date="wizard.date.value"
        :start-at="wizard.startAt.value"
        :quote="wizard.quote.value"
        :pets="wizard.pets.value"
      />

      <p v-if="wizard.quoteFailed.value && wizard.current.value === 'pets'" class="text-sm font-medium text-destructive" role="alert">
        {{ $t("client.booking.quoteFailed") }}
      </p>

      <div class="flex items-center justify-between gap-3 border-t pt-5">
        <Button v-if="wizard.stepIndex.value > 0" variant="outline" class="h-11 rounded-full px-5" :disabled="wizard.saving.value" @click="wizard.back">
          {{ $t("petCare.common.back") }}
        </Button>
        <span v-else />
        <Button
          v-if="wizard.current.value !== 'confirm'"
          class="h-11 rounded-full bg-sage px-6 hover:bg-sage/90"
          :disabled="!wizard.canNext.value || wizard.quoting.value" @click="wizard.next">
          {{ $t("client.booking.next") }}
        </Button>
        <Button v-else class="h-11 rounded-full bg-sage px-6 hover:bg-sage/90" :disabled="wizard.saving.value" @click="wizard.submit">
          <Loader2 v-if="wizard.saving.value" class="mr-2 size-4 animate-spin" />
          {{ $t("client.booking.confirm") }}
        </Button>
      </div>
    </div>
  </section>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Loader2 } from "lucide-vue-next";
import EmptyState from "@/components/shop/EmptyState.vue";
import { Button } from "@/components/ui/button";
import { useBookingWizard } from "@/composables/spa/useBookingWizard";
import BookingDone from "./components/BookingDone.vue";
import BookingSteps from "./components/BookingSteps.vue";
import StepBranch from "./components/StepBranch.vue";
import StepConfirm from "./components/StepConfirm.vue";
import StepPets from "./components/StepPets.vue";
import StepSlot from "./components/StepSlot.vue";

const wizard = useBookingWizard();
const branchName = computed(() => wizard.branches.value.find((b) => b.id === wizard.branchId.value)?.name ?? "");
</script>
