import { reactive, ref, watch, type Ref } from "vue";
import { useSaveProductBrand } from "@/features/shared/products";
import type { ProductBrand } from "@bongcun/supabase/products";

/** The add/edit form of a brand: filled when the dialog opens, saved with the shared mutation. */
export const useBrandForm = (open: Ref<boolean>, brand: Ref<ProductBrand | null>, close: () => void) => {
  const form = reactive({ name: "", imageUrl: "", isActive: true });
  const submitted = ref(false);
  const mutation = useSaveProductBrand();

  watch(
    () => open.value,
    (isOpen) => {
      if (!isOpen) return;
      form.name = brand.value?.name ?? "";
      form.imageUrl = brand.value?.imageUrl ?? "";
      form.isActive = brand.value?.isActive ?? true;
      submitted.value = false;
    },
    { immediate: true }
  );

  const submit = async () => {
    submitted.value = true;
    if (!form.name.trim()) return;
    try {
      await mutation.mutateAsync({ id: brand.value?.id, name: form.name, imageUrl: form.imageUrl, isActive: form.isActive });
      close();
    } catch {
      // the mutation already showed the failure toast
    }
  };

  return { form, submitted, saving: mutation.isPending, submit };
};
