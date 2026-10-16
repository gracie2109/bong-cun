<template>
  <Sheet :open="open" @update:open="close">
    <SheetContent side="right" class="flex w-full flex-col gap-0 p-0 sm:max-w-xl">
      <SheetTitle class="sr-only">{{ $t("pageFields.customers.form.title") }}</SheetTitle>
      <SheetDescription class="sr-only">{{ $t("pageFields.customers.form.subtitle") }}</SheetDescription>
      <InfomationForm
        :form="form"
        :loading="loading"
        :list-user-group="[]"
        :addressModel="addressModel"
        @on-submit="submit"
        @close-dialog="close"
      />
    </SheetContent>
  </Sheet>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { useForm } from "vee-validate";
import { Sheet, SheetContent, SheetDescription, SheetTitle } from "@/components/ui/sheet";
import { BASE_GENDER } from "@/lib/constants";
import { useCreateUser } from "@/queries/users";
import { initAddress, type IAddress } from "@/types/location.type";
import type { IUser } from "@/types/user.type";
import InfomationForm from "./components/InfomationForm.vue";

defineProps<{ open: boolean }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const addressModel = ref<IAddress>({ ...initAddress });
const form = useForm<IUser>({
  initialValues: {
    province: initAddress,
    password: "",
    fullName: "",
    phoneNumber: "",
    photoURL: "",
    email: "",
    gender: BASE_GENDER[0].value,
    displayName: "",
    groupIds: null,
  },
});

const createUser = useCreateUser();
const loading = computed(() => createUser.isPending.value);

const close = () => {
  form.resetForm();
  emit("update:open", false);
};

const submit = form.handleSubmit(async (value: any) => {
  try {
    await createUser.mutateAsync({
      email: value.email,
      password: value.password,
      displayName: value.displayName,
      fullName: value.fullName,
      phoneNumber: value.phoneNumber,
      gender: value.gender,
      address: value.province,
      photoURL: value.photoURL,
    });
  } catch {
    return; // the mutation already showed the failure toast; keep the dialog open
  }
  close();
});
</script>
