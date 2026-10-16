import { computed, ref, watch } from "vue";
import { useRouter } from "vue-router";
import { toast } from "vue-sonner";
import i18n from "@/i18n";
import { usePlaceShopOrder } from "@/queries/shopOrders";
import { useShopPublicSettings } from "@/queries/shop";
import { orderErrorDetail, orderErrorHint } from "@/repositories/shop";
import { useAuthStore, useCart } from "@/stores";
import type { DeliveryMethod } from "@/types/shopOrder";
import { lineKey } from "@/utils/shop/cart";
import { checkoutErrors, newClientRef, pickupReceiver, toCartInput } from "@/utils/shop/order";
import { useCartView } from "./useCartView";
import { useCheckoutAddress } from "./useCheckoutAddress";
import { useShippingQuote } from "./useShippingQuote";

/** State and actions of the /checkout page. */
export const useCheckout = () => {
  const cart = useCart();
  const auth = useAuthStore();
  const router = useRouter();
  const view = useCartView();
  const settingsQuery = useShopPublicSettings();
  const settings = computed(() => settingsQuery.data.value);
  const address = useCheckoutAddress();
  const placeOrder = usePlaceShopOrder();

  // ------------------------------------------------------------ how to receive it
  /** The ways this cart can be received: in-store-only items rule delivery out. */
  const methods = computed<DeliveryMethod[]>(() => {
    const list: DeliveryMethod[] = [];
    if (settings.value?.allowCod && !view.inStoreOnly.value) list.push("delivery");
    if (settings.value?.allowPickup) list.push("pickup");
    return list;
  });
  const chosen = ref<DeliveryMethod>("delivery");
  const method = computed<DeliveryMethod | null>(() =>
    methods.value.includes(chosen.value) ? chosen.value : (methods.value[0] ?? null)
  );
  const isDelivery = computed(() => method.value === "delivery");

  // Whoever picks the order up; filled from the account, editable.
  const receiverName = ref("");
  const receiverPhone = ref("");
  watch(
    () => auth.currentUser,
    (user) => {
      if (!user) return;
      if (!receiverName.value) receiverName.value = user.fullName ?? user.displayName ?? "";
      if (!receiverPhone.value) receiverPhone.value = user.phoneNumber ?? "";
    },
    { immediate: true }
  );

  // --------------------------------------------------------------------- money
  const shipping = useShippingQuote({
    settings,
    address: address.selected,
    goodsG: view.weightG,
    subtotal: view.subtotal,
    enabled: isDelivery,
  });
  const shippingFee = computed(() => (isDelivery.value ? shipping.fee.value : 0));
  const total = computed(() => view.subtotal.value + shippingFee.value);
  const overCodLimit = computed(
    () => isDelivery.value && settings.value !== undefined && total.value > settings.value.codMax
  );

  // --------------------------------------------------------------------- order
  const note = ref("");
  const submitted = ref(false);
  /** One reference per order: pressing the button twice, or retrying after a timeout, cannot make two. */
  const clientRef = ref(newClientRef());

  const errors = computed(() =>
    checkoutErrors({
      method: method.value ?? "delivery",
      address: address.selected.value,
      receiverName: receiverName.value,
      receiverPhone: receiverPhone.value,
    })
  );

  const blocked = computed(
    () =>
      method.value === null ||
      view.hasIssue.value ||
      view.lines.value.length === 0 ||
      (isDelivery.value && (shipping.tooHeavy.value || overCodLimit.value))
  );

  const explain = (error: unknown) => {
    const hint = orderErrorHint(error);
    const t = i18n.global.t;
    if (!hint) {
      toast.error(t("shop.checkout.errors.generic"));
      return;
    }
    toast.error(t(`shop.checkout.errors.${hint}`, { names: orderErrorDetail(error) }));
  };

  const submit = async () => {
    submitted.value = true;
    if (blocked.value || !method.value || Object.keys(errors.value).length > 0) return;
    try {
      const placed = await placeOrder.mutateAsync({
        clientRef: clientRef.value,
        deliveryMethod: method.value,
        addressId: isDelivery.value ? (address.selected.value?.id ?? null) : null,
        receiver: isDelivery.value ? null : pickupReceiver(receiverName.value, receiverPhone.value),
        lines: toCartInput(view.lines.value),
        shippingFeeQuote: isDelivery.value ? shippingFee.value : null,
        note: note.value,
      });
      cart.removeMany(view.lines.value.map(lineKey));
      void router.replace({ name: "order-detail", params: { code: placed.code }, query: { placed: "1" } });
    } catch (error) {
      explain(error);
      // The cart may be out of date (price, stock); look again.
      void view.refresh();
    }
  };

  return {
    ...view,
    settings,
    settingsLoading: settingsQuery.isLoading,
    address,
    methods,
    method,
    isDelivery,
    setMethod: (next: DeliveryMethod) => (chosen.value = next),
    receiverName,
    receiverPhone,
    shipping,
    shippingFee,
    total,
    overCodLimit,
    note,
    submitted,
    errors,
    blocked,
    placing: placeOrder.isPending,
    submit,
  };
};
