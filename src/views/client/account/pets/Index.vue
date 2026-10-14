<template>
  <section class="max-w-4xl space-y-4 pb-12">
    <div class="flex items-center justify-between gap-3">
      <div>
        <h2 class="text-lg font-semibold">{{ $t("client.pets.title") }}</h2>
        <p class="text-sm text-muted-foreground">{{ $t("client.pets.intro") }}</p>
      </div>
      <Button v-if="page.hasCustomer.value" @click="page.openNew">
        <Plus class="mr-1 size-4" />
        {{ $t("client.pets.add") }}
      </Button>
    </div>

    <p v-if="page.loading.value" class="py-8 text-center text-muted-foreground">{{ $t("petCare.common.loading") }}</p>
    <div v-else-if="page.failed.value" class="py-12 text-center">
      <p class="mb-3 text-muted-foreground">{{ $t("client.pets.loadFailed") }}</p>
      <Button variant="outline" @click="page.retry">{{ $t("client.catalog.retry") }}</Button>
    </div>
    <div v-else-if="!page.hasCustomer.value" class="rounded-xl border border-dashed py-12 text-center">
      <p class="mb-3 text-muted-foreground">{{ $t("client.pets.needProfile") }}</p>
      <Button as-child variant="outline">
        <RouterLink :to="{ name: 'account-profile' }">{{ $t("client.pets.goProfile") }}</RouterLink>
      </Button>
    </div>
    <div v-else-if="page.pets.value.length === 0" class="rounded-xl border border-dashed py-12 text-center text-muted-foreground">
      {{ $t("client.pets.empty") }}
    </div>
    <div v-else class="grid gap-3 sm:grid-cols-2">
      <PetCard
        v-for="pet in page.pets.value"
        :key="pet.id"
        :pet="pet"
        @edit="page.openEdit(pet)"
        @hide="page.toHide.value = pet"
      />
    </div>

    <PetFormDialog
      v-model:open="page.open.value"
      :form="page.form"
      :errors="page.errors.value"
      :submitted="page.submitted.value"
      :saving="page.saving.value"
      :editing="page.editingId.value !== null"
      :species="page.species.value"
      @submit="page.submit"
    />

    <DialogConfirm
      :open="page.toHide.value !== null"
      danger
      :title="$t('client.pets.hideTitle')"
      :desc="$t('client.pets.hideDesc', { name: page.toHide.value?.name ?? '' })"
      :ok-btn="$t('client.pets.hide')"
      @handle-ok="page.confirmHide"
      @open-change="page.toHide.value = null"
      @cancel="page.toHide.value = null"
    />
  </section>
</template>

<script lang="ts" setup>
import { Plus } from "lucide-vue-next";
import { DialogConfirm } from "@/components/common";
import { Button } from "@/components/ui/button";
import { useMyPets } from "@/composables/account/useMyPets";
import PetCard from "./components/PetCard.vue";
import PetFormDialog from "./components/PetFormDialog.vue";

const page = useMyPets();
</script>
