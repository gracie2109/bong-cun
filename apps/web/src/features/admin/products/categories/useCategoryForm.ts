import { reactive, ref, watch, type Ref } from "vue";
import { useSaveProductCategory } from "@/features/shared/products";
import type { ProductCategory } from "@bongcun/supabase/products";

/** The add/edit form of a category: filled when the dialog opens, saved with the shared mutation. */
export const useCategoryForm = (open: Ref<boolean>, category: Ref<ProductCategory | null>, close: () => void) => {
  const form = reactive({ name: "", parentId: "", parentName: "", imageUrl: "", isActive: true });
  const submitted = ref(false);
  const mutation = useSaveProductCategory();

  watch(
    () => open.value,
    (isOpen) => {
      if (!isOpen) return;
      form.name = category.value?.name ?? "";
      form.parentId = category.value?.parentId ?? "";
      form.parentName = category.value?.parentName ?? "";
      form.imageUrl = category.value?.imageUrl ?? "";
      form.isActive = category.value?.isActive ?? true;
      submitted.value = false;
    },
    { immediate: true }
  );

  const submit = async () => {
    submitted.value = true;
    if (!form.name.trim()) return;
    try {
      await mutation.mutateAsync({
        id: category.value?.id,
        parentId: form.parentId || null,
        name: form.name,
        imageUrl: form.imageUrl,
        isActive: form.isActive,
      });
      close();
    } catch {
      // the mutation already showed the failure toast
    }
  };

  return { form, submitted, saving: mutation.isPending, submit };
};
