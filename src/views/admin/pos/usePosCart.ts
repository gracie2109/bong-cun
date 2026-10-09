import { computed, reactive, ref, watch, watchEffect, type Ref } from "vue";
import { useI18n } from "vue-i18n";
import { usePermission } from "@/composables/usePermission";
import { useCustomerPets, useFetchServicePrice } from "@/queries/pos";
import { DISCOUNT_LIMIT } from "@/repositories/pos";
import type { CatalogItem } from "./catalog";
import type { Buyer } from "./components/CustomerPanel.vue";
import { parseAmount } from "./format";

export type CartLine = { key: string; item: CatalogItem; qty: number; petId: string | null };

/** The sale being rung up: buyer, lines with their prices, discount and what blocks checkout. */
export const usePosCart = (branchId: Ref<string | undefined>, hasShift: Ref<boolean>) => {
  const { t } = useI18n();
  const { canUpdate: canDiscountMore } = usePermission("pos");

  const buyer = ref<Buyer | null>(null);
  const lines = ref<CartLine[]>([]);
  const discountText = ref("");
  const note = ref("");
  let nextKey = 0;

  const petsQuery = useCustomerPets(computed(() => buyer.value?.customerId));
  const pets = computed(() => (buyer.value?.customerId ? petsQuery.data.value ?? [] : []));

  const addItem = (item: CatalogItem) => {
    // Scanning the same product again adds one more; services and combos get a line per pet.
    const existing = item.type === "product" ? lines.value.find((line) => line.item.id === item.id) : undefined;
    if (existing) {
      existing.qty += 1;
      return;
    }
    const onlyPet = pets.value.length === 1 ? pets.value[0].id : null;
    lines.value.push({ key: String(nextKey++), item, qty: 1, petId: item.type === "product" ? null : onlyPet });
  };

  const removeLine = (key: string) => {
    lines.value = lines.value.filter((line) => line.key !== key);
  };

  const changeQty = (line: CartLine, delta: number) => {
    const next = line.qty + delta;
    if (next <= 0) removeLine(line.key);
    else line.qty = next;
  };

  const setPet = (line: CartLine, petId: string | null) => {
    line.petId = petId;
  };

  // A different buyer means different pets: drop pets that are no longer theirs.
  watch(pets, (list) => {
    const ids = new Set(list.map((pet) => pet.id));
    const onlyPet = list.length === 1 ? list[0].id : null;
    for (const line of lines.value) {
      if (line.item.type === "product") continue;
      if (line.petId && !ids.has(line.petId)) line.petId = null;
      if (!line.petId && onlyPet) line.petId = onlyPet;
    }
  });

  // -------------------------------------------------- by-weight price preview
  const fetchServicePrice = useFetchServicePrice();
  const weightPrices = reactive<Record<string, number | null | "loading">>({});
  const weightKey = (line: CartLine) => `${branchId.value ?? ""}:${line.item.id}:${line.petId ?? ""}`;

  watchEffect(() => {
    const branch = branchId.value;
    if (!branch) return;
    for (const line of lines.value) {
      if (line.item.type !== "service" || line.item.price !== null || !line.petId) continue;
      const key = weightKey(line);
      if (key in weightPrices) continue;
      const pet = pets.value.find((item) => item.id === line.petId);
      if (!pet?.weightKg) {
        weightPrices[key] = null;
        continue;
      }
      weightPrices[key] = "loading";
      fetchServicePrice({ speciesId: pet.speciesId, serviceId: line.item.id, weightKg: pet.weightKg, branchId: branch })
        .then((price) => (weightPrices[key] = price))
        .catch(() => (weightPrices[key] = null));
    }
  });

  /** The price shown for a line; null while a by-weight service cannot be priced yet. */
  const unitPrice = (line: CartLine): number | null => {
    if (line.item.price !== null) return line.item.price;
    const price = weightPrices[weightKey(line)];
    return typeof price === "number" ? price : null;
  };

  const lineProblem = (line: CartLine): string => {
    if (line.item.type === "product" || line.item.price !== null) return "";
    if (!buyer.value?.customerId) return t("pos.cart.needCustomerPet");
    if (!line.petId) return t("pos.cart.needPet");
    const pet = pets.value.find((item) => item.id === line.petId);
    if (!pet?.weightKg) return t("pos.cart.needWeight");
    const price = weightPrices[weightKey(line)];
    if (price === "loading") return "";
    return price === null ? t("pos.cart.noPrice") : "";
  };

  const subtotal = computed(() => lines.value.reduce((sum, line) => sum + (unitPrice(line) ?? 0) * line.qty, 0));
  const discount = computed(() => parseAmount(discountText.value));
  const total = computed(() => Math.max(0, subtotal.value - discount.value));

  const discountProblem = computed(() => {
    if (discount.value > subtotal.value) return t("pos.cart.discountTooHigh");
    if (discount.value > subtotal.value * DISCOUNT_LIMIT && !canDiscountMore.value) return t("pos.errors.discount_limit");
    return "";
  });

  const checkoutBlocker = computed(() => {
    if (!hasShift.value) return t("pos.errors.no_open_shift");
    if (lines.value.length === 0) return "";
    if (lines.value.some((line) => unitPrice(line) === null)) return t("pos.cart.unpriced");
    return discountProblem.value;
  });
  const canCheckout = computed(() => lines.value.length > 0 && !checkoutBlocker.value);

  const resetSale = () => {
    buyer.value = null;
    lines.value = [];
    discountText.value = "";
    note.value = "";
  };

  return {
    buyer,
    lines,
    pets,
    discountText,
    note,
    subtotal,
    discount,
    total,
    discountProblem,
    checkoutBlocker,
    canCheckout,
    addItem,
    removeLine,
    changeQty,
    setPet,
    unitPrice,
    lineProblem,
    resetSale,
  };
};
