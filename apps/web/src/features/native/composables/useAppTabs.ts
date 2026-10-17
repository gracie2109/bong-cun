import { computed } from "vue";
import { storeToRefs } from "pinia";
import { useCart, useAuthStore } from "@/stores";
import { APP_TABS, tabForRoute, type AppTab } from "../helpers/tabs";

/** State and navigation for the bottom tab bar. */
export const useAppTabs = () => {
  const route = useRoute();
  const router = useRouter();
  const cart = useCart();
  const { currentUser } = storeToRefs(useAuthStore());

  const activeTab = computed(() => tabForRoute(route.name as string | undefined));
  const cartCount = computed(() => cart.lines.length);

  const badgeFor = (tab: AppTab) => (tab.id === "cart" ? cartCount.value : 0);

  const open = (tab: AppTab) => {
    // Guests have no account page: the Account tab leads them to sign in instead of bouncing to home.
    const name = tab.id === "account" && !currentUser.value ? "login" : tab.routeName;
    router.push({ name });
  };

  return { tabs: APP_TABS, activeTab, badgeFor, open };
};
