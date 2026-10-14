<template>
  <section class="mx-auto max-w-3xl space-y-6 px-4 pb-16 pt-6">
    <header>
      <h1 class="text-2xl font-bold">{{ $t("client.booking.title") }}</h1>
    </header>

    <p v-if="wizard.loading.value" class="py-12 text-center text-muted-foreground">{{ $t("petCare.common.loading") }}</p>

    <BookingDone v-else-if="wizard.result.value" :code="wizard.result.value.code" />

    <div v-else-if="!wizard.hasCustomer.value" class="rounded-xl border border-dashed py-12 text-center">
      <p class="mb-3 text-muted-foreground">{{ $t("client.booking.needProfile") }}</p>
      <Button as-child variant="outline">
        <RouterLink :to="{ name: 'account-profile' }">{{ $t("client.pets.goProfile") }}</RouterLink>
      </Button>
    </div>
    <div v-else-if="wizard.pets.value.length === 0" class="rounded-xl border border-dashed py-12 text-center">
      <p class="mb-3 text-muted-foreground">{{ $t("client.booking.needPet") }}</p>
      <Button as-child variant="outline">
        <RouterLink :to="{ name: 'account-pets' }">{{ $t("client.booking.addPet") }}</RouterLink>
      </Button>
    </div>

    <template v-else>
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

      <p v-if="wizard.quoteFailed.value && wizard.current.value === 'pets'" class="text-sm text-red-600">
        {{ $t("client.booking.quoteFailed") }}
      </p>

      <div class="flex items-center justify-between gap-3 border-t pt-4">
        <Button v-if="wizard.stepIndex.value > 0" variant="outline" :disabled="wizard.saving.value" @click="wizard.back">
          {{ $t("petCare.common.back") }}
        </Button>
        <span v-else />
        <Button v-if="wizard.current.value !== 'confirm'" :disabled="!wizard.canNext.value || wizard.quoting.value" @click="wizard.next">
          {{ $t("client.booking.next") }}
        </Button>
        <Button v-else :disabled="wizard.saving.value" @click="wizard.submit">
          <Loader2 v-if="wizard.saving.value" class="mr-2 size-4 animate-spin" />
          {{ $t("client.booking.confirm") }}
        </Button>
      </div>
    </template>
  </section>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Loader2 } from "lucide-vue-next";
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
