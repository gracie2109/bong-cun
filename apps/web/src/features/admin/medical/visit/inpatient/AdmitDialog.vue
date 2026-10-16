<template>
  <AppDialog
    :open="open"
    :title="$t('medical.admit.title', { name: visit.petName })"
    :description="needIsolation ? $t('medical.admit.isolationHint') : undefined"
    :ok-text="$t('medical.admit.ok')"
    :ok-disabled="!kennelId"
    :busy="admitting.isPending.value"
    form-id="admit-form"
    size="sm"
    @update:open="emit('update:open', $event)"
  >
    <form id="admit-form" class="space-y-4" @submit.prevent="submit">
      <div class="space-y-1.5">
        <Label>{{ $t("medical.admit.kennel") }}</Label>
        <Skeleton v-if="kennelsQuery.isPending.value" class="h-10 w-full" />
        <p v-else-if="options.length === 0" class="text-sm text-muted-foreground">{{ $t("medical.admit.noKennel") }}</p>
        <div v-else class="grid gap-2 sm:grid-cols-2">
          <button
            v-for="kennel in options"
            :key="kennel.id"
            type="button"
            :disabled="!kennel.free"
            class="rounded-lg border px-3 py-2 text-left text-sm transition-colors disabled:cursor-not-allowed disabled:opacity-40"
            :class="kennelId === kennel.id ? 'border-primary bg-primary/10' : 'bg-white hover:bg-muted'"
            @click="kennelId = kennel.id"
          >
            <span class="block font-semibold">{{ kennel.code }}</span>
            <span class="text-xs text-muted-foreground">
              {{ $t(`medical.ward.purpose.${kennel.purpose}`) }} · {{ kennel.typeName }}
              <template v-if="!kennel.free"> · {{ $t("medical.admit.busy") }}</template>
            </span>
          </button>
        </div>
      </div>
      <div class="space-y-1.5">
        <Label for="admit-out">{{ $t("medical.admit.plannedOut") }}</Label>
        <Input id="admit-out" v-model="plannedOut" type="datetime-local" />
      </div>
      <div class="space-y-1.5">
        <Label for="admit-note">{{ $t("medical.ward.note") }}</Label>
        <Input id="admit-note" v-model="note" />
      </div>
    </form>
  </AppDialog>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Skeleton } from "@/components/ui/skeleton";
import { useAdmitInpatient, useInpatientKennels } from "@/queries/inpatient";
import type { MedicalVisitDetail } from "@bongcun/core/medical";
import { toIso } from "@/features/admin/schedule/format";

const props = defineProps<{ open: boolean; visit: MedicalVisitDetail }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const admitting = useAdmitInpatient();
const kennelsQuery = useInpatientKennels(computed(() => props.visit.branchId), computed(() => props.open));
const needIsolation = computed(() => props.visit.diagnoses.some((diagnosis) => diagnosis.isContagious));
// A contagious case only goes to an isolation kennel; the others to any.
const options = computed(() =>
  (kennelsQuery.data.value ?? []).filter((kennel) => !needIsolation.value || kennel.purpose === "isolation")
);

const kennelId = ref("");
const plannedOut = ref("");
const note = ref("");
watch(() => props.open, (isOpen) => {
  if (!isOpen) return;
  kennelId.value = "";
  plannedOut.value = "";
  note.value = "";
});

const submit = async () => {
  if (!kennelId.value) return;
  try {
    await admitting.mutateAsync({
      visitId: props.visit.id,
      input: { kennelId: kennelId.value, plannedOutAt: plannedOut.value ? toIso(...(plannedOut.value.split("T") as [string, string])) : null, note: note.value.trim() },
    });
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
