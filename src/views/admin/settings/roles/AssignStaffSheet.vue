<template>
  <Sheet :open="open" @update:open="emit('update:open', $event)">
    <SheetContent side="right" class="flex w-full flex-col gap-0 p-0 sm:max-w-md">
      <SheetHeader class="border-b px-6 py-4">
        <SheetTitle>{{ $t("rbac.assign.title", { role }) }}</SheetTitle>
        <SheetDescription class="sr-only">{{ $t("rbac.subtitle") }}</SheetDescription>
      </SheetHeader>

      <form id="assign-staff-form" class="flex-1 space-y-5 overflow-y-auto px-6 py-5" @submit.prevent="submit">
        <p v-if="staff.length === 0" class="rounded-lg bg-muted/60 px-3 py-2 text-sm text-muted-foreground">
          {{ $t("rbac.assign.noStaff") }}
        </p>

        <div class="space-y-2">
          <Label>{{ $t("rbac.assign.staff") }}</Label>
          <Select v-model="staffId">
            <SelectTrigger :aria-label="$t('rbac.assign.staff')">
              <SelectValue :placeholder="$t('rbac.assign.pickStaff')" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem v-for="member in staff" :key="member.id" :value="member.id">
                {{ member.name }}<span v-if="member.email" class="text-muted-foreground"> · {{ member.email }}</span>
              </SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div v-if="branches.length > 1" class="space-y-2">
          <Label>{{ $t("rbac.assign.branch") }}</Label>
          <Select v-model="branchId">
            <SelectTrigger :aria-label="$t('rbac.assign.branch')"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem v-for="branch in branches" :key="branch.id" :value="branch.id">
                {{ branch.code }} · {{ branch.name }}
              </SelectItem>
            </SelectContent>
          </Select>
        </div>

        <p v-if="currentRole && currentRole !== role" class="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-700">
          {{ $t("rbac.assign.current", { role: roleLabel(currentRole) }) }}.
          {{ $t("rbac.assign.replaceNote", { role }) }}
        </p>
      </form>

      <SheetFooter class="gap-2 border-t px-6 py-4">
        <Button type="button" variant="outline" @click="emit('update:open', false)">
          {{ $t("petCare.common.cancel") }}
        </Button>
        <Button type="submit" form="assign-staff-form" :disabled="!member || !branchId || saveStaff.isPending.value">
          {{ $t("petCare.common.save") }}
        </Button>
      </SheetFooter>
    </SheetContent>
  </Sheet>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Sheet, SheetContent, SheetDescription, SheetFooter, SheetHeader, SheetTitle } from "@/components/ui/sheet";
import { useSaveStaffAssignments } from "@/queries/staff";
import type { Branch } from "@/repositories/branches";
import type { Role } from "@/repositories/roles";
import type { StaffMember } from "@/repositories/staff";

const props = defineProps<{
  open: boolean;
  role: string;
  roles: Role[];
  staff: StaffMember[];
  branches: Branch[];
}>();

const emit = defineEmits<{ "update:open": [value: boolean] }>();

const saveStaff = useSaveStaffAssignments();

const staffId = ref<string>();
const branchId = ref<string>();

watch(
  () => props.open,
  (open) => {
    if (!open) return;
    staffId.value = undefined;
    branchId.value = props.branches[0]?.id;
  }
);

const member = computed(() => props.staff.find((item) => item.id === staffId.value));
const currentRole = computed(
  () => member.value?.assignments.find((item) => item.branchId === branchId.value)?.role ?? null
);

const roleLabel = (name: string): string => {
  const found = props.roles.find((item) => item.name === name);
  return found?.description ? `${found.description} (${name})` : name;
};

const submit = async () => {
  if (!member.value || !branchId.value) return;
  const assignments = [
    ...member.value.assignments.filter((item) => item.branchId !== branchId.value),
    { branchId: branchId.value, role: props.role },
  ];
  try {
    await saveStaff.mutateAsync({ userId: member.value.id, assignments });
  } catch {
    return; // the mutation already showed the failure toast
  }
  emit("update:open", false);
};
</script>
