<template>
  <div class="space-y-6">
    <div class="flex flex-wrap gap-6">
      <div
        class="h-28 w-28 rounded-sm border cursor-pointer"
        @click="() => (open = !open)"
      >
        <div class="text-center w-full h-full m-auto grid place-items-center">
          <PlusCircle class="size-6" />
          new permisson
        </div>
      </div>
      <ListPermissions
        :data="permissions"
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
      <DialogContent>
        <PermissionForm
          :loading="loading"
          :form="form"
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
import PermissionForm from "./components/PermissionForm.vue";
import { computed, ref } from "vue";
import {
  useCreatePermission,
  useDeletePermission,
  usePermissionsList,
  useUpdatePermission,
} from "@/queries/permissions";
import { PlusCircle } from "lucide-vue-next";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import ListPermissions from "./components/ListPermissions.vue";
import { DialogConfirm } from "@/components/common";

const form = useForm();
const permissionsQuery = usePermissionsList();
const permissions = computed(() => permissionsQuery.data.value ?? []);
const pageCount = computed(() => permissions.value.length);
const createPermission = useCreatePermission();
const updatePermission = useUpdatePermission();
const deletePermission = useDeletePermission();
const loading = computed(
  () =>
    permissionsQuery.isPending.value ||
    createPermission.isPending.value ||
    updatePermission.isPending.value ||
    deletePermission.isPending.value
);
const elSelect = ref();
const open = ref(false);
const openDelete = ref(false);

const handleSubmit = form.handleSubmit(async (value: any) => {
  try {
    if (!elSelect.value) {
      await createPermission.mutateAsync(value);
      form.resetForm();
    } else {
      await updatePermission.mutateAsync({ id: elSelect.value.id, input: value });
    }
  } catch {
    return; // the mutation already showed the failure toast; keep the dialog open
  }
  open.value = !open.value;
});

const closeDialog = () => {
  form.resetForm();
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
    await deletePermission.mutateAsync(elSelect.value.id);
  } catch {
    // the mutation already showed the failure toast
  } finally {
    openDelete.value = false;
    elSelect.value = [];
  }
};
</script>
