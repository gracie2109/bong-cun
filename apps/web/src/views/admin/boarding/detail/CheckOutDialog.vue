<template>
  <AppDialog
    :open="open"
    :title="$t('boarding.checkOut.title', { code: stay.code })"
    :description="$t('boarding.checkOut.subtitle')"
    :ok-text="$t('boarding.detail.checkOut')"
    :ok-disabled="!preview"
    :busy="checkingOut.isPending.value"
    size="md"
    persistent
    @update:open="emit('update:open', $event)"
    @ok="submit"
  >
    <p v-if="previewQuery.isPending.value" class="text-sm text-muted-foreground">{{ $t("petCare.common.loading") }}</p>
    <div v-else-if="preview" class="space-y-4">
      <ul class="divide-y rounded-lg border">
        <li v-for="(line, index) in preview.items" :key="index" class="flex items-center justify-between gap-3 px-3 py-2 text-sm">
          <div>
            <p class="font-medium">{{ line.name }}</p>
            <p class="text-xs text-muted-foreground">{{ line.petName }} · {{ line.qty }} × {{ money(line.unitPrice) }}</p>
          </div>
          <span class="font-semibold">{{ money(line.amount) }}</span>
        </li>
        <li class="flex items-center justify-between px-3 py-2 text-base font-bold">
          <span>{{ $t("boarding.detail.total") }}</span>
          <span>{{ money(preview.total) }}</span>
        </li>
      </ul>

      <section v-if="pending.length" class="space-y-2">
        <p class="text-sm font-semibold">{{ $t("boarding.checkOut.belongings") }}</p>
        <label v-for="item in pending" :key="item.stayPetId" class="flex items-start gap-2 text-sm">
          <Checkbox :checked="returned.has(item.stayPetId)" @update:checked="(value: boolean | 'indeterminate') => toggle(item.stayPetId, value === true)" />
          <span><span class="font-medium">{{ item.petName }}</span>: {{ item.belongings }}</span>
        </label>
        <p v-if="unreturned" class="text-xs font-semibold text-amber-700">{{ $t("boarding.checkOut.remind") }}</p>
      </section>
    </div>
  </AppDialog>
</template>

<script lang="ts" setup>
import { computed, ref, toRef, watch } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import { Checkbox } from "@/components/ui/checkbox";
import { useCheckOutBoarding, useCheckoutPreview } from "@/queries/boarding";
import type { BoardingStay } from "@bongcun/core/boarding";
import { money } from "../format";

const props = defineProps<{ open: boolean; stay: BoardingStay }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const checkingOut = useCheckOutBoarding();
const previewQuery = useCheckoutPreview(
  computed(() => props.stay.id),
  toRef(props, "open")
);
const preview = computed(() => previewQuery.data.value ?? null);

// Belongings still with the hotel; ticked ones are handed back with this check-out.
const pending = computed(() => (preview.value?.belongings ?? []).filter((item) => !item.returned));
const returned = ref(new Set<string>());
const unreturned = computed(() => pending.value.some((item) => !returned.value.has(item.stayPetId)));

watch(
  () => props.open,
  () => (returned.value = new Set())
);

const toggle = (id: string, on: boolean) => {
  const next = new Set(returned.value);
  if (on) next.add(id);
  else next.delete(id);
  returned.value = next;
};

const submit = async () => {
  try {
    await checkingOut.mutateAsync({ id: props.stay.id, returnedPetIds: [...returned.value] });
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
