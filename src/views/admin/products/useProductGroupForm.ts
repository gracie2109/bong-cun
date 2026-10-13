import { computed, reactive, ref, watch, type Ref } from "vue";
import { useI18n } from "vue-i18n";
import { useProductAttributes, useProductGroup, useSaveProductGroup } from "@/queries/products";
import type { ProductGroup } from "@/repositories/products";
import { parseAmount } from "@/views/admin/pos/format";
import { attributeError, commitDraft } from "./productVariantForm";
import { useProductVariants } from "./useProductVariants";

export type ProductTab = "general" | "variants";

/** Everything the product sheet edits: the group's own fields plus its attributes and variants. */
export const useProductGroupForm = (open: Ref<boolean>, groupId: Ref<string | null>, close: () => void) => {
  const { t } = useI18n();

  const form = reactive({
    name: "",
    desc: "",
    imageUrl: "",
    isActive: true,
    categoryId: "",
    categoryName: "",
    brandId: "",
    brandName: "",
  });
  const { attributes, rows, bulk, fill: fillVariants } = useProductVariants();
  const submitted = ref(false);
  const tab = ref<string>("general");

  const groupQuery = useProductGroup(computed(() => (open.value && groupId.value) || undefined));
  const attributesQuery = useProductAttributes();
  const knownAttributes = computed(() => attributesQuery.data.value ?? []);
  const mutation = useSaveProductGroup();
  const loading = computed(() => Boolean(groupId.value) && groupQuery.isPending.value);

  const fill = (group: ProductGroup | null) => {
    form.name = group?.name ?? "";
    form.desc = group?.desc ?? "";
    form.imageUrl = group?.imageUrl ?? "";
    form.isActive = group?.isActive ?? true;
    form.categoryId = group?.categoryId ?? "";
    form.categoryName = group?.categoryName ?? "";
    form.brandId = group?.brandId ?? "";
    form.brandName = group?.brandName ?? "";
    submitted.value = false;
    tab.value = "general";
    fillVariants(group);
  };

  watch(
    () => [open.value, groupId.value, groupQuery.data.value] as const,
    ([isOpen, id, group]) => {
      if (!isOpen) return;
      if (!id) fill(null);
      else if (group && group.id === id) fill(group);
    },
    { immediate: true }
  );

  /** Tabs that hold a mistake, shown after the first save attempt. */
  const tabErrors = computed<Record<ProductTab, boolean>>(() => ({
    general: submitted.value && !form.name.trim(),
    variants:
      submitted.value &&
      (attributes.value.some((attribute) => attributeError(attributes.value, attribute, t)) ||
        rows.value.some((row) => !row.unit.trim())),
  }));

  const submit = async () => {
    for (const attribute of attributes.value) commitDraft(attribute);
    submitted.value = true;
    if (tabErrors.value.general || tabErrors.value.variants) {
      tab.value = tabErrors.value.general ? "general" : "variants";
      return;
    }

    try {
      await mutation.mutateAsync({
        id: groupId.value ?? undefined,
        name: form.name,
        desc: form.desc,
        imageUrl: form.imageUrl,
        isActive: form.isActive,
        categoryId: form.categoryId || null,
        brandId: form.brandId || null,
        attributes: attributes.value.map((attribute) => ({ name: attribute.name.trim(), values: attribute.values })),
        variants: rows.value.map((row) => ({
          id: row.id,
          options: row.options,
          sku: row.sku,
          barcode: row.barcode,
          unit: row.unit,
          price: parseAmount(row.price),
          trackStock: row.trackStock,
          isActive: row.isActive,
          imageUrl: row.imageUrl,
        })),
      });
      close();
    } catch {
      // the mutation already showed the failure toast
    }
  };

  return {
    form,
    attributes,
    rows,
    bulk,
    knownAttributes,
    submitted,
    tab,
    tabErrors,
    loading,
    saving: computed(() => mutation.isPending.value),
    submit,
  };
};
