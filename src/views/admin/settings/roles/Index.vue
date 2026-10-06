<template>
  <div class="space-y-6">
    <div class="flex flex-wrap gap-6">
      <div
        class="h-28 w-28 rounded-sm border cursor-pointer"
        @click="() => (open = !open)"
      >
        <div class="text-center w-full h-full m-auto grid place-items-center">
          <PlusCircle class="size-6" />
          new role
        </div>
      </div>
      <ListRoles
        :data="roles"
        :loading="loading"
        :total-record="pageCount"
        @open-permission="handleOpenPermission"
        @delete-item="onDelete"
        :elSelect="elSelect"
      />
    </div>

    <Dialog
      :open="open"
      @update:open="
        () => {
          open = !open;
          elSelect = [];
        }
      "
    >
      <DialogContent class="max-w-screen-xl h-[800px]">
        <PermissionForm
          :loading="loading"
          :form="form"
          :permissions="permissions"
          :isEditSuccess="isEditSuccess"
          @on-submit="handleSubmit"
          @close-dialog="closeDialog"
          :elSelect="elSelect"
        />
      </DialogContent>
    </Dialog>

    <DialogConfirm
      @change-open="
        () => {
          elSelect = null;
          open = !open;
        }
      "
      :open="openDelete"
      :title="elSelect?.name"
      @cancel="
        () => {
          elSelect = null;
          openDelete = false;
        }
      "
      @handleOk="handleDelete"
    />
  </div>
</template>

<script setup lang="ts">
import { useForm } from "vee-validate";
import PermissionForm from "./components/RoleForm.vue";
import { computed, ref } from "vue";
import { useCreateRole, useDeleteRole, useRolesList, useUpdateRole } from "@/queries/roles";
import { usePermissionsList } from "@/queries/permissions";
import { PlusCircle } from "lucide-vue-next";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import ListRoles from "./components/ListRoles.vue";
import { DialogConfirm } from "@/components/common";

const form = useForm();
const rolesQuery = useRolesList();
const roles = computed(() => rolesQuery.data.value ?? []);
const pageCount = computed(() => roles.value.length);
const { data: permissionOptions } = usePermissionsList();
const permissions = computed(() => permissionOptions.value ?? []);
const createRole = useCreateRole();
const updateRole = useUpdateRole();
const deleteRole = useDeleteRole();
const loading = computed(
  () =>
    rolesQuery.isPending.value ||
    createRole.isPending.value ||
    updateRole.isPending.value ||
    deleteRole.isPending.value
);
const elSelect = ref();
const open = ref(false);
const openDelete = ref(false);
const isEditSuccess = ref(false);

const handleSubmit = form.handleSubmit(async (value: any) => {
  try {
    if (!elSelect.value) {
      await createRole.mutateAsync(value);
    } else {
      await updateRole.mutateAsync({ id: elSelect.value.id, input: value });
      isEditSuccess.value = true;
    }
  } catch {
    return; // the mutation already showed the failure toast; keep the dialog open
  }
  closeDialog();
});

const closeDialog = () => {
  form.resetForm();
  form.handleReset();
  open.value = !open.value;
  elSelect.value = [];
};

const handleOpenPermission = (item: any) => {
  elSelect.value = item.res;
  open.value = true;
  form.setValues({ ...item.res });
};
const onDelete = (item: any) => {
  elSelect.value = item.res;
  openDelete.value = true;
};
const handleDelete = async () => {
  try {
    await deleteRole.mutateAsync(elSelect.value.id);
  } catch {
    // the mutation already showed the failure toast
  } finally {
    openDelete.value = false;
    elSelect.value = [];
  }
};
</script>
