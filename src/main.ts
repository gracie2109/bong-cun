import "./assets/index.css";

import { createApp } from "vue";
import i18n from "./i18n";
import App from "./App.vue";
import router from "./router";
import { setupStore } from "@/stores";
import { VueQueryPlugin } from "@tanstack/vue-query";
import { createQueryClient } from "@/plugins/query-client";

const app = createApp(App);

setupStore(app);
app.use(VueQueryPlugin, { queryClient: createQueryClient() });
app.use(router);
app.use(i18n)

app.mount("#app");
