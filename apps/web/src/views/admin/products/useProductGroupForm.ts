import { computed, reactive, ref, watch, type Ref } from "vue";
import { useI18n } from "vue-i18n";
import { supabaseClient } from "@/lib/supabase";
import { useSaveBranchPrices } from "@/queries/branchPrices";
import { useProductAttributes, useProductGroup, useSaveProductGroup } from "@/queries/products";
import type { ProductGroup } from "@bongcun/supabase/products";
import { deleteImagesQuietly } from "@bongcun/supabase/storage";
import { parseAmount } from "@/views/admin/pos/format";
import { useImageGallery } from "./images/useImageGallery";
import { useBranchPriceGrid } from "./prices/useBranchPriceGrid";
import { attributeError, commitDraft } from "./productVariantForm";
import { hasUnitProblem, toUnitInput } from "./units/productUnitForm";
import { useProductVariants } from "./useProductVariants";

export type ProductTab = "general" | "images" | "variants" | "units" | "branchPrices";

/** Everything the product sheet edits: the group's own fields plus its attributes and variants. */
export const useProductGroupForm = (open: Ref<boolean>, groupId: Ref<string | null>, close: () => void) => {
  const { t } = useI18n();

  const form = reactive({
    name: "",
    desc: "",
    isActive: true,
    categoryId: "",
    categoryName: "",
    brandId: "",
    brandName: "",
  });
  const { attributes, rows, bulk, fill: fillVariants } = useProductVariants();
  // Uploads go to catalog/<group id>; a new group has no id yet, so it gets a throwaway folder name.
  const draftFolder = globalThis.crypto.randomUUID();
  const gallery = useImageGallery(computed(() => groupId.value ?? draftFolder));
  const submitted = ref(false);
  const tab = ref<string>("general");

  const groupQuery = useProductGroup(computed(() => (open.value && groupId.value) || undefined));
  const attributesQuery = useProductAttributes();
  const knownAttributes = computed(() => attributesQuery.data.value ?? []);
  const mutation = useSaveProductGroup();
  const priceGrid = useBranchPriceGrid(open, rows);
  const pricesMutation = useSaveBranchPrices();
  const loading = computed(() => Boolean(groupId.value) && groupQuery.isPending.value);

  const fill = (group: ProductGroup | null) => {
    form.name = group?.name ?? "";
    form.desc = group?.desc ?? "";
    form.isActive = group?.isActive ?? true;
    form.categoryId = group?.categoryId ?? "";
    form.categoryName = group?.categoryName ?? "";
    form.brandId = group?.brandId ?? "";
    form.brandName = group?.brandName ?? "";
    submitted.value = false;
    tab.value = "general";
    fillVariants(group);
    gallery.fill(group?.images ?? []);
  };

  // A variant cannot keep a picture that was taken out of the gallery.
  watch(
    () => gallery.images.value.map((image) => image.url),
    (urls) => {
      for (const row of rows.value) if (row.imageUrl && !urls.includes(row.imageUrl)) row.imageUrl = "";
    }
  );

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
    images: false,
    units: submitted.value && rows.value.some((row) => hasUnitProblem(row.units, row.unit)),
    branchPrices: false,
    variants:
      submitted.value &&
      (attributes.value.some((attribute) => attributeError(attributes.value, attribute, t)) ||
        rows.value.some((row) => !row.unit.trim())),
  }));

  const submit = async () => {
    for (const attribute of attributes.value) commitDraft(attribute);
    submitted.value = true;
    if (tabErrors.value.general || tabErrors.value.variants || tabErrors.value.units) {
      tab.value = tabErrors.value.general ? "general" : tabErrors.value.variants ? "variants" : "units";
      return;
    }

    // Read before saving: saving reloads the group, which refills the grid.
    const priceChanges = priceGrid.changes();
    try {
      await mutation.mutateAsync({
        id: groupId.value ?? undefined,
        name: form.name,
        desc: form.desc,
        imageUrl: gallery.images.value[0]?.url ?? "",
        isActive: form.isActive,
        images: gallery.images.value.map((image) => ({ url: image.url, storagePath: image.storagePath })),
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
          weightG: row.weightG.trim() ? parseAmount(row.weightG) : null,
          shipPolicy: row.shipPolicy,
          units: row.units.map(toUnitInput),
        })),
      });
      // Files of pictures taken out of the gallery; a failure only leaves them behind.
      void deleteImagesQuietly(supabaseClient(), gallery.removedPaths());
    } catch {
      return; // the mutation already showed the failure toast
    }

    // Branch prices go through their own call (the permission is checked per branch); if one
    // fails the sheet stays open so the cells can be fixed and saved again.
    try {
      if (priceChanges.length) await pricesMutation.mutateAsync(priceChanges);
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
    gallery,
    priceGrid,
    submitted,
    tab,
    tabErrors,
    loading,
    saving: computed(() => mutation.isPending.value || pricesMutation.isPending.value),
    submit,
  };
};
