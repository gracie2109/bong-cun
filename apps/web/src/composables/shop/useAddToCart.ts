import { computed, ref, watch, type Ref } from "vue";
import { useRouter } from "vue-router";
import { toast } from "vue-sonner";
import i18n from "@/i18n";
import { sellableUnits, type ProductVariant } from "@bongcun/supabase/products";
import { useCart } from "@/stores";

export type UnitOption = { id: string | null; label: string; price: number };

/** "Add to cart" for the picked variant: which unit it is sold in, how many, and the toast after. */
export const useAddToCart = (variant: Ref<ProductVariant | undefined>) => {
  const cart = useCart();
  const router = useRouter();
  const t = i18n.global.t;

  const unitId = ref<string | null>(null);
  const quantity = ref(1);

  /** The variant's own unit first, then every unit it is sold in (thùng, hộp...). */
  const unitOptions = computed<UnitOption[]>(() => {
    const picked = variant.value;
    if (!picked) return [];
    return [
      { id: null, label: picked.unit, price: picked.price },
      ...sellableUnits(picked.units).map((unit) => ({
        id: unit.id,
        label: `${unit.name} (×${unit.factor})`,
        price: unit.price ?? picked.price * unit.factor,
      })),
    ];
  });

  const price = computed(() => unitOptions.value.find((option) => option.id === unitId.value)?.price ?? null);

  const reset = () => {
    unitId.value = null;
    quantity.value = 1;
  };
  // Another variant may not have the unit that was picked.
  watch(variant, () => (unitId.value = null));

  /** Puts the picked variant in the cart; returns false when nothing was added. */
  const add = (): boolean => {
    const picked = variant.value;
    if (!picked) return false;
    const result = cart.add(picked.id, unitId.value, quantity.value);
    if (result === "cart_full") {
      toast.error(t("shop.cart.full"));
      return false;
    }
    toast.success(t("shop.added", { name: picked.name }), {
      description: result === "capped" ? t("shop.cart.cappedQty") : undefined,
      action: { label: t("shop.cart.viewCart"), onClick: () => void router.push({ name: "cart" }) },
    });
    return true;
  };

  return { unitId, quantity, unitOptions, price, add, reset };
};
