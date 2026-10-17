<template>
  <div v-if="groupId" class="flex items-start justify-between gap-4 rounded-lg border p-3">
    <div class="space-y-0.5">
      <Label for="group-clinic-only">{{ $t("products.form.clinicOnly") }}</Label>
      <p class="text-xs text-muted-foreground">{{ $t("products.form.clinicOnlyHint") }}</p>
    </div>
    <Switch
      id="group-clinic-only"
      :checked="query.data.value === true"
      :disabled="query.isPending.value || mutation.isPending.value"
      @update:checked="(value: boolean) => mutation.mutate({ groupId: groupId as string, value })"
    />
  </div>
</template>

<script lang="ts" setup>
import { toRef } from "vue";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { useClinicOnly, useSetClinicOnly } from "@/features/admin/products/queries/productClinicOnly";

/** Medicine sold only at the clinic: saved at once, apart from the product form. */
const props = defineProps<{ groupId: string | null }>();
const query = useClinicOnly(toRef(props, "groupId"));
const mutation = useSetClinicOnly();
</script>
