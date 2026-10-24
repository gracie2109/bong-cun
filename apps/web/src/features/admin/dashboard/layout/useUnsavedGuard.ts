import { onBeforeUnmount, onMounted, type Ref } from "vue";
import { onBeforeRouteLeave, onBeforeRouteUpdate } from "vue-router";
import i18n from "@/i18n";

/** Asks before leaving the page, or switching dashboard, while the layout has unsaved changes. */
export const useUnsavedGuard = (dirty: Ref<boolean>) => {
  const question = () => window.confirm(i18n.global.t("dashboard.layout.discardAsk"));
  onBeforeRouteLeave(() => !dirty.value || question());
  onBeforeRouteUpdate(() => !dirty.value || question());

  const onUnload = (event: BeforeUnloadEvent) => {
    if (dirty.value) event.preventDefault();
  };
  onMounted(() => window.addEventListener("beforeunload", onUnload));
  onBeforeUnmount(() => window.removeEventListener("beforeunload", onUnload));
};
