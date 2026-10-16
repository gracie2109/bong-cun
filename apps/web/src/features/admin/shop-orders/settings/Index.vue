<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <ShoppingBag class="size-4 text-primary" />
      {{ $t("shop.settings.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-5 overflow-y-auto">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <ShopOrdersNav />
        <Button v-if="canEdit" :disabled="!dirty || saving" @click="save">
          <Loader2 v-if="saving" class="mr-1 size-4 animate-spin" />
          {{ $t("petCare.common.save") }}
        </Button>
      </div>

      <p v-if="!canEdit" class="rounded-lg border border-dashed bg-white px-4 py-3 text-sm text-muted-foreground">
        {{ $t("shop.settings.readOnly") }}
      </p>

      <template v-if="query.data.value">
        <div class="grid gap-5 xl:grid-cols-2">
          <MethodsCard :form="form" :branches="branches" :errors="submittedErrors" :disabled="!canEdit" />
          <PickupCard :form="form" :disabled="!canEdit" />
        </div>
        <ShippingCard :form="form" :errors="submittedErrors" :disabled="!canEdit" />
      </template>
      <p v-else-if="query.isLoading.value" class="text-sm text-muted-foreground">{{ $t("petCare.common.loading") }}</p>
    </div>
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Loader2, ShoppingBag } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { useShopSettingsForm } from "@/composables/shop/useShopSettingsForm";
import { useBranches } from "@/queries/branches";
import { ContentWrap, Header } from "@/features/admin/components";
import ShopOrdersNav from "../ShopOrdersNav.vue";
import MethodsCard from "./components/MethodsCard.vue";
import PickupCard from "./components/PickupCard.vue";
import ShippingCard from "./components/ShippingCard.vue";

const { form, query, canEdit, dirty, errors, submitted, saving, save } = useShopSettingsForm();
const branchesQuery = useBranches();
const branches = computed(() => (branchesQuery.data.value ?? []).filter((branch) => branch.isActive));
// Errors only show after a save attempt so a fresh form is not covered in red.
const submittedErrors = computed(() => (submitted.value ? errors.value : []));
</script>
