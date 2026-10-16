import { computed } from "vue";
import { useRouter } from "vue-router";
import { useAuthStore } from "@/stores";
import { useCart } from "@/stores";
import { useCartView } from "./useCartView";

/** State and actions of the /cart page. */
export const useCartPage = () => {
  const cart = useCart();
  const auth = useAuthStore();
  const router = useRouter();
  const view = useCartView();

  const isEmpty = computed(() => cart.lines.length === 0);
  const canCheckout = computed(() => !isEmpty.value && !view.loading.value && !view.failed.value && !view.hasIssue.value);

  /** Guests sign in first and come back to the checkout. */
  const goCheckout = () => {
    if (!canCheckout.value) return;
    if (!auth.isAuthenticated) {
      void router.push({ name: "login", query: { redirect: "/checkout" } });
      return;
    }
    void router.push({ name: "checkout" });
  };

  return { cart, ...view, isEmpty, canCheckout, goCheckout };
};
