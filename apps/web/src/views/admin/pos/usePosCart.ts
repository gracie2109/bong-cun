import { computed, reactive, ref, watch, watchEffect, type Ref } from "vue";
import { useI18n } from "vue-i18n";
import { usePermission } from "@/composables/usePermission";
import { useCustomerPets, useFetchServicePrice } from "@/queries/pos";
import { DISCOUNT_LIMIT } from "@/repositories/pos";
import type { BillableTicket } from "@/repositories/spa";
import type { BillableBoardingStay } from "@bongcun/core/boarding";
import type { BillableVisit } from "@bongcun/core/medical";
import type { ProductUnit } from "@/repositories/products";
import type { CatalogItem } from "./catalog";
import type { Buyer } from "./components/CustomerPanel.vue";
import { parseAmount } from "./format";
import { itemInUnit } from "./unitPricing";

/**
 * `appointmentItemId` marks a finished spa ticket, `boardingChargeId` a charge of a checked-out stay and
 * `medicalItemId` a line of a signed visit: all come with a fixed price and quantity, one per sale.
 */
export type CartLine = {
  key: string;
  item: CatalogItem;
  qty: number;
  petId: string | null;
  appointmentItemId?: string;
  boardingChargeId?: string;
  medicalItemId?: string;
};

const isFixedLine = (line: CartLine) => !!line.appointmentItemId || !!line.boardingChargeId || !!line.medicalItemId;

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
    // Scanning the same product (in the same unit) again adds one more; services and combos get a line per pet.
    const existing =
      item.type === "product"
        ? lines.value.find((line) => line.item.id === item.id && (line.item.unitId ?? null) === (item.unitId ?? null))
        : undefined;
    if (existing) {
      existing.qty += 1;
      return;
    }
    const onlyPet = pets.value.length === 1 ? pets.value[0].id : null;
    lines.value.push({ key: String(nextKey++), item, qty: 1, petId: item.type === "product" ? null : onlyPet });
  };

  const addTicket = (ticket: BillableTicket) => {
    if (lines.value.some((line) => line.appointmentItemId === ticket.id)) return;
    lines.value.push({
      key: String(nextKey++),
      item: {
        type: ticket.type,
        id: ticket.id,
        name: ticket.petName ? `${ticket.name} · ${ticket.petName}` : ticket.name,
        price: ticket.unitPrice,
        unit: null,
        hint: ticket.code,
      },
      qty: 1,
      petId: ticket.petId,
      appointmentItemId: ticket.id,
    });
  };

  /** Puts every unpaid charge of a checked-out stay in the cart. */
  const addBoardingStay = (stay: BillableBoardingStay) => {
    for (const charge of stay.charges) {
      if (lines.value.some((line) => line.boardingChargeId === charge.id)) continue;
      lines.value.push({
        key: String(nextKey++),
        item: {
          type: "service",
          id: charge.id,
          name: charge.petName ? `${charge.name} · ${charge.petName}` : charge.name,
          price: charge.unitPrice,
          unit: null,
          hint: stay.code,
        },
        qty: charge.qty,
        petId: null,
        boardingChargeId: charge.id,
      });
    }
  };

  /** Puts every unpaid line of a signed visit in the cart. */
  const addMedicalVisit = (visit: BillableVisit) => {
    for (const item of visit.items) {
      if (lines.value.some((line) => line.medicalItemId === item.id)) continue;
      lines.value.push({
        key: String(nextKey++),
        item: {
          type: item.kind,
          id: item.id,
          name: `${item.name} · ${visit.petName}`,
          price: item.unitPrice,
          unit: item.unitName,
          hint: visit.code,
        },
        qty: item.qty,
        petId: null,
        medicalItemId: item.id,
      });
    }
  };

  const removeLine = (key: string) => {
    lines.value = lines.value.filter((line) => line.key !== key);
  };

  const changeQty = (line: CartLine, delta: number) => {
    const next = line.qty + delta;
    if (next <= 0) removeLine(line.key);
    else line.qty = next;
  };

  /** Sells the line's product in another of its units (null: the base unit); the price follows. */
  const changeUnit = (line: CartLine, unit: ProductUnit | null) => {
    line.item = itemInUnit(line.item, unit);
  };

  const setPet = (line: CartLine, petId: string | null) => {
    line.petId = petId;
  };

  // Spa tickets and stay charges belong to one customer: a different buyer drops them.
  watch(
    () => buyer.value?.customerId,
    () => {
      lines.value = lines.value.filter((line) => !isFixedLine(line));
    }
  );

  // A different buyer means different pets: drop pets that are no longer theirs.
  watch(pets, (list) => {
    const ids = new Set(list.map((pet) => pet.id));
    const onlyPet = list.length === 1 ? list[0].id : null;
    for (const line of lines.value) {
      if (line.item.type === "product" || isFixedLine(line)) continue;
      if (line.petId && !ids.has(line.petId)) line.petId = null;
      if (!line.petId && onlyPet) line.petId = onlyPet;
    }
  });

  // -------------------------------------------------- by-weight price preview
  const fetchServicePrice = useFetchServicePrice();
  const weightPrices = reactive<Record<string, number | null | "loading">>({});
  // The pet's weight is part of the key, so correcting it prices the line again.
  const weightKey = (line: CartLine) => {
    const weight = pets.value.find((item) => item.id === line.petId)?.weightKg ?? "";
    return `${branchId.value ?? ""}:${line.item.id}:${line.petId ?? ""}:${weight}`;
  };

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
    addTicket,
    addBoardingStay,
    addMedicalVisit,
    removeLine,
    changeQty,
    changeUnit,
    setPet,
    unitPrice,
    lineProblem,
    resetSale,
  };
};
