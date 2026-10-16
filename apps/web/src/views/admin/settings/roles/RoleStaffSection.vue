<template>
  <section ref="section" class="rounded-xl border bg-white">
    <div class="flex items-center justify-between gap-3 border-b px-5 py-3">
      <h4 class="font-semibold">{{ $t("rbac.roles.staff", { n: holders.length }) }}</h4>
      <Button v-if="canManage" type="button" variant="ghost" size="sm" class="text-primary" @click="assignOpen = true">
        <UserPlus class="mr-2 size-4" />
        {{ $t("rbac.roles.assign") }}
      </Button>
    </div>
    <p v-if="holders.length === 0" class="px-5 py-6 text-center text-sm text-muted-foreground">
      {{ $t("rbac.roles.staffEmpty") }}
    </p>
    <ul v-else class="grid gap-2 p-3 sm:grid-cols-2">
      <li
        v-for="holder in holders"
        :key="`${holder.staff.id}-${holder.branchId}`"
        class="flex items-center gap-3 rounded-lg border px-3 py-2"
      >
        <Avatar class="size-9">
          <AvatarImage v-if="holder.staff.photoUrl" :src="holder.staff.photoUrl" />
          <AvatarFallback class="bg-primary/10 text-xs text-primary">{{ initials(holder.staff.name) }}</AvatarFallback>
        </Avatar>
        <div class="min-w-0 flex-1">
          <p class="truncate text-sm font-semibold">{{ holder.staff.name }}</p>
          <p class="truncate text-xs text-muted-foreground">{{ branchName(holder.branchId) }}</p>
        </div>
        <Button
          v-if="canManage"
          type="button"
          variant="ghost"
          size="sm"
          class="text-red-600 hover:text-red-700"
          :disabled="saveStaff.isPending.value"
          @click="removeHolder(holder.staff, holder.branchId)"
        >
          {{ $t("rbac.roles.remove") }}
        </Button>
      </li>
    </ul>

    <AssignStaffSheet
      v-model:open="assignOpen"
      :role="role.name"
      :staff="staff"
      :branches="branches"
      :roles="roles"
    />
  </section>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { UserPlus } from "lucide-vue-next";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { useSaveStaffAssignments } from "@/queries/staff";
import type { Branch } from "@/repositories/branches";
import type { Role } from "@/repositories/roles";
import type { StaffMember } from "@/repositories/staff";
import { initials } from "@/views/admin/pets/format";
import AssignStaffSheet from "./AssignStaffSheet.vue";

const props = defineProps<{
  role: Role;
  roles: Role[];
  staff: StaffMember[];
  branches: Branch[];
  canManage: boolean;
}>();

const saveStaff = useSaveStaffAssignments();

const section = ref<HTMLElement | null>(null);
const assignOpen = ref(false);

const holders = computed(() =>
  props.staff.flatMap((member) =>
    member.assignments
      .filter((item) => item.role === props.role.name)
      .map((item) => ({ staff: member, branchId: item.branchId }))
  )
);

const branchName = (id: string): string => {
  const branch = props.branches.find((item) => item.id === id);
  return branch ? `${branch.code} · ${branch.name}` : "";
};

const removeHolder = (member: StaffMember, branchId: string) =>
  saveStaff.mutate({
    userId: member.id,
    assignments: member.assignments.filter((item) => item.branchId !== branchId),
  });

defineExpose({ scrollIntoView: () => section.value?.scrollIntoView({ behavior: "smooth" }) });
</script>
