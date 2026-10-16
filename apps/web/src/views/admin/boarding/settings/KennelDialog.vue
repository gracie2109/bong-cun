<template>
  <AppDialog
    :open="open"
    :title="kennel ? $t('boarding.kennels.edit') : $t('boarding.kennels.add')"
    :ok-text="$t('petCare.common.save')"
    :ok-disabled="!canSave"
    :busy="mutation.isPending.value"
    form-id="kennel-form"
    size="md"
    @update:open="emit('update:open', $event)"
  >
    <form id="kennel-form" class="space-y-4" @submit.prevent="submit">
      <div class="grid grid-cols-2 gap-3">
        <div class="space-y-1">
          <Label for="kennel-code">{{ $t("boarding.kennels.code") }}</Label>
          <Input id="kennel-code" v-model="draft.code" :placeholder="$t('boarding.kennels.codePlaceholder')" />
        </div>
        <div class="space-y-1">
          <Label for="kennel-name">{{ $t("boarding.kennels.name") }}</Label>
          <Input id="kennel-name" v-model="draft.name" />
        </div>
      </div>
      <div class="space-y-1">
        <Label>{{ $t("boarding.kennels.type") }}</Label>
        <Select v-model="draft.kennelTypeId">
          <SelectTrigger :aria-label="$t('boarding.kennels.type')"><SelectValue :placeholder="$t('boarding.kennels.pickType')" /></SelectTrigger>
          <SelectContent>
            <SelectItem v-for="item in types" :key="item.id" :value="item.id">{{ item.name }}</SelectItem>
          </SelectContent>
        </Select>
      </div>
      <div class="grid grid-cols-2 items-end gap-3">
        <div class="space-y-1">
          <Label for="kennel-sort">{{ $t("boarding.common.sortOrder") }}</Label>
          <Input id="kennel-sort" v-model="draft.sortOrder" type="number" step="1" />
        </div>
        <label class="flex items-center gap-2 pb-2 text-sm">
          <Switch v-model="draft.isActive" :aria-label="$t('boarding.common.active')" />
          {{ $t("boarding.common.active") }}
        </label>
      </div>
    </form>
  </AppDialog>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";
import { useSaveKennel } from "@/queries/boarding";
import type { Kennel, KennelType } from "@/types/boarding";

const props = defineProps<{ open: boolean; branchId: string | undefined; kennel: Kennel | null; types: KennelType[] }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const mutation = useSaveKennel();

const emptyDraft = () => ({ code: "", name: "", kennelTypeId: "", sortOrder: "0", isActive: true });
const draft = ref(emptyDraft());
const canSave = computed(() => !!props.branchId && !!draft.value.code.trim() && !!draft.value.kennelTypeId);

watch(
  () => props.open,
  (isOpen) => {
    if (!isOpen) return;
    const kennel = props.kennel;
    draft.value = kennel
      ? { code: kennel.code, name: kennel.name ?? "", kennelTypeId: kennel.kennelTypeId, sortOrder: String(kennel.sortOrder), isActive: kennel.isActive }
      : emptyDraft();
  },
  { immediate: true }
);

const submit = async () => {
  if (!canSave.value || !props.branchId) return;
  try {
    await mutation.mutateAsync({
      input: {
        branchId: props.branchId,
        kennelTypeId: draft.value.kennelTypeId,
        code: draft.value.code.trim(),
        name: draft.value.name.trim() || null,
        isActive: draft.value.isActive,
        sortOrder: Number(draft.value.sortOrder) || 0,
      },
      id: props.kennel?.id,
    });
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
