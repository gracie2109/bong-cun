import { ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";

/** The header search box: shows the product list's current search and opens the list with a new one. */
export const useHeaderSearch = () => {
  const route = useRoute();
  const router = useRouter();
  const text = ref("");

  watch(
    () => (route.name === "products" ? String(route.query.q ?? "") : ""),
    (q) => (text.value = q),
    { immediate: true }
  );

  const submit = () => {
    const q = text.value.trim();
    void router.push({ name: "products", query: q ? { ...(route.name === "products" ? route.query : {}), q } : {} });
  };

  return { text, submit };
};
