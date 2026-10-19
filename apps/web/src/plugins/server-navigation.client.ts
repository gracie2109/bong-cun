import { START_LOCATION } from "vue-router";
import { needsDocumentLoad } from "@/utils/shop/serverRendered";

// On the website, moving to another server-rendered page loads it from the server instead of
// fetching its data in the browser, so the data is in the HTML. The app build has no server and
// keeps its in-app navigation.
export default defineNuxtPlugin(() => {
  if (useRuntimeConfig().public.appTarget === "mobile") return;

  useRouter().beforeEach((to, from) => {
    if (from === START_LOCATION) return;
    if (!needsDocumentLoad(from.fullPath, to.fullPath)) return;
    window.location.assign(to.fullPath);
    return false;
  });
});
