<template>
  <div
    class="flex w-full h-full items-center justify-center cursor-pointer"
    @click="() => (open = !open)"
  >
    <Plus class="size-4 mr-2" />
    <span class="font-semibold" v-if="!props.title">
      {{ $t("common.create") }} {{ $t("pageMeta.services") }}
    </span>
    <span class="font-semibold" v-else>
      {{ props.title }}
    </span>
  </div>

  <Dialog
    :open="open"
    @update:open="
      () => {
        open = !open;
        $emit('updateOpen', open);
      }
    "
  >
    <DialogContent class="w-[90vw]">
      <DialogHeader>
        <DialogTitle>
          {{
            !props.elSelect
              ? $t("pageFields.pets.addNewServiceTitle")
              : $t("pageFields.pets.editServiceTitle")
          }}
        </DialogTitle>
      </DialogHeader>
      <div class="h-[650px] overflow-y-auto p-3">
        <ServiceForm
          :elSelect="props.elSelect"
          :form="form"
          :show-btn="false"
          @on-submit="handleForm"
          :default-pet="props.defaultPet  || []"
        />
      </div>

      <DialogFooter class="p-6 pt-0">
        <Button
          type="button"
          variant="outline"
          @click="
            () => {
              open = !open;
              form.resetForm();
              $emit('updateOpen', open);
            }
          "
        >
          Cancel
        </Button>
        <Button type="submit" @click="handleForm"> Save changes </Button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>

<script setup lang="ts">
import { ref, watch } from "vue";
import { Plus } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import ServiceForm from "@/views/admin/pets/services/components/ServiceForm.vue";
import { useForm } from "vee-validate";
import { useCreatePetService, useUpdatePetService } from "@/queries/petServices";
const props = defineProps<{
  title?: string;
  handleOpen?: boolean;
  elSelect?: any;
  defaultPet?:any[]
}>();
const open = ref(false);
const form = useForm();
const createService = useCreatePetService();
const updateService = useUpdatePetService();

const emits = defineEmits(["updateOpen", "setElSelect"]);

watch(
  () => props.handleOpen,
  () => {
    if (props.handleOpen) {
      open.value = props.handleOpen;
    }
  }
);

const handleForm = form.handleSubmit(async (values: any) => {
  const isEdit = !!props.elSelect;
  try {
    if (!isEdit) {
      await createService.mutateAsync(values);
    } else {
      await updateService.mutateAsync({ id: props.elSelect.id, input: values });
    }
  } catch {
    return; // the mutation already showed the failure toast; keep the dialog open
  }

  open.value = !open.value;
  form.resetForm();
  if (isEdit) {
    emits("setElSelect");
    emits("updateOpen");
  }
});
watch(
  () => props.elSelect,
  () => {
    if (props.elSelect) {
      form.setValues({ ...props.elSelect }, true);
    }
  }
);
</script>
