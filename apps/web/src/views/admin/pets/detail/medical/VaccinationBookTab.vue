<template>
  <div class="space-y-4">
    <div class="flex flex-wrap items-center justify-between gap-2">
      <p class="text-sm text-muted-foreground">{{ $t("medical.book.petHint") }}</p>
      <Button v-if="canAdd" size="sm" variant="outline" @click="addOpen = true">
        <Plus class="mr-1 size-4" />{{ $t("medical.book.addExternal") }}
      </Button>
    </div>

    <p v-if="bookQuery.isPending.value" class="py-6 text-center text-sm text-muted-foreground">{{ $t("petCare.common.loading") }}</p>
    <VaccineBookList v-else :entries="book" :can-void="canVoid" @void="voiding = $event" />

    <ExternalVaccineDialog v-model:open="addOpen" :pet-id="petId" :book="book" />
    <VoidDoseDialog :open="!!voiding" :busy="voidBusy" @update:open="voiding = null" @confirm="confirmVoid" />
  </div>
</template>

<script lang="ts" setup>
import { toRef } from "vue";
import { Plus } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import VaccineBookList from "@/views/admin/medical/book/VaccineBookList.vue";
import VoidDoseDialog from "@/views/admin/medical/book/VoidDoseDialog.vue";
import ExternalVaccineDialog from "./ExternalVaccineDialog.vue";
import { useVaccinationBook } from "./useVaccinationBook";

const props = defineProps<{ petId: string }>();

const { bookQuery, book, canAdd, canVoid, addOpen, voiding, confirmVoid, voidBusy } = useVaccinationBook(toRef(props, "petId"));
</script>
