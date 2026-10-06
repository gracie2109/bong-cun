<template>
  <Dialog :open="props.open && props.data" @update:open="$emit('updateOpen')">
    <DialogContent>
      <DialogHeader class="p-6 pb-0">
        <DialogTitle> {{ $t("pageFields.pets.editPrice") }}</DialogTitle>
      </DialogHeader>
      <div>
        <form @submit="onSubmit">
          <FormField v-slot="{ componentField }" name="username">
            <FormItem>
              <FormLabel>Name</FormLabel>
              <FormControl>
                <Input
                  type="text"
                  placeholder="shadcn"
                  v-bind="componentField"
                  :default-value="props.data.name"
                  disabled
                />
              </FormControl>
              <FormMessage />
            </FormItem>
          </FormField>

          <FormField
            v-slot="{ componentField }"
            type="radio"
            name="generalPrice"
          >
            <FormItem class="space-y-3">
              <FormLabel>General Price</FormLabel>

              <FormControl>
                <Input
                  type="number"
                  v-bind="componentField"
                  size="sm"
                  :default-value="props.data.generalPrice"
                />
              </FormControl>
              <FormMessage />
            </FormItem>
          </FormField>

          <div class="mt-5 flex w-full justify-end gap-3">
            <Button type="button" variant="outline" @click="$emit('updateOpen')"
            >Cancel</Button
          >
          <Button type="submit">Save</Button>
          </div>
        </form>
      </div>
    </DialogContent>
  </Dialog>
</template>

<script lang="ts" setup>
import Button from "@/components/ui/button/Button.vue";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  FormField,
  FormMessage,
  FormControl,
  FormItem,
} from "@/components/ui/form";
import FormLabel from "@/components/ui/form/FormLabel.vue";
import Input from "@/components/ui/input/Input.vue";
import { useUpdateGeneralPrice } from "@/queries/petServices";
import { useForm } from "vee-validate";

const props = defineProps<{
  data: any;
  open: boolean;
}>();
const form = useForm();
const updateGeneralPrice = useUpdateGeneralPrice();
const onSubmit = form.handleSubmit(async (values) => {
    const price = values.generalPrice;
    try {
        await updateGeneralPrice.mutateAsync({
            id: props.data.id,
            generalPrice: price === "" || price == null ? null : Number(price),
        });
    } catch {
        // the mutation already showed the failure toast
    }
});
const emits = defineEmits(["updateOpen"]);
</script>
