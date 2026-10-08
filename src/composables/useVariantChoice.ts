import { computed, ref, watch, type Ref } from "vue";
import type { ProductGroup, ProductVariant } from "@/repositories/products";

/**
 * Picking one variant of a group by its attribute values (Vị: Gà, Khối lượng: 85g...).
 * `canSell` says whether a variant can be picked right now (for example: it has stock).
 * Values that no sellable variant has with the other picks are marked unavailable; picking one
 * anyway keeps it and clears the other picks that no longer fit.
 */
export const useVariantChoice = (
  group: Ref<ProductGroup | null | undefined>,
  canSell: (variant: ProductVariant) => boolean = () => true
) => {
  const picks = ref<(string | null)[]>([]);

  const variants = computed(() => (group.value?.variants ?? []).filter((variant) => variant.isActive));
  const attributes = computed(() => group.value?.attributes ?? []);

  const fits = (variant: ProductVariant, skip = -1) =>
    picks.value.every((value, index) => index === skip || value === null || variant.options[index] === value);

  const isAvailable = (index: number, value: string) =>
    variants.value.some((variant) => canSell(variant) && variant.options[index] === value && fits(variant, index));

  const pick = (index: number, value: string) => {
    const next = [...picks.value];
    next[index] = value;
    // Clear the other picks that no variant has together with this value.
    next.forEach((other, otherIndex) => {
      if (otherIndex === index || other === null) return;
      const together = variants.value.some(
        (variant) => variant.options[index] === next[index] && variant.options[otherIndex] === other
      );
      if (!together) next[otherIndex] = null;
    });
    picks.value = next;
  };

  /** The variant matching every pick, once each attribute has one. */
  const variant = computed<ProductVariant | undefined>(() => {
    if (picks.value.some((value) => value === null)) return undefined;
    return variants.value.find((item) => item.options.every((value, index) => value === picks.value[index]));
  });

  // Start on the first sellable variant so the common case is one click.
  const reset = () => {
    const first = variants.value.find(canSell) ?? variants.value[0];
    picks.value = attributes.value.map((_, index) => first?.options[index] ?? null);
  };
  watch(() => variants.value.map((item) => item.id).join(), reset, { immediate: true });

  return { attributes, variants, picks, pick, isAvailable, variant, reset };
};
