import * as Vue from "vue";

import { createRouter, createWebHistory } from "vue-router";

import ComboServiceView from "@/views/admin/pets/service-combo/Index.vue";
import ContactView from "@/views/client/contact/ContactView.vue";
import DashboardView from "@/views/admin/dashboard/DashboardView.vue";
import DetailPetServicePrice from "@/views/admin/pets/services-price/Detail.vue";
import DetailScheduleOrder from "@/views/admin/schedule/order-services/detail/Index.vue"
import ForgotPassView from "@/views/auth/ForgotPassView.vue";
import HomeView from "@/views/home/HomeView.vue";
import ListPetServices from "@/views/admin/pets/services/Index.vue";
import ListPets from "@/views/admin/pets/Index.vue";
import ListScheduleOrder from "@/views/admin/schedule/order-services/list/Index.vue";
import ListUserGroupView from "@/views/admin/users/user-groups/Index.vue";
import ListUserView from "@/views/admin/users/ListView.vue";
import LoginView from "@/views/auth/LoginView.vue";
import NotFoundPage from "@/components/NotFoundPage.vue";
import { PAGE_LAYOUT } from "@/lib/constants";
import PermissionView from "@/views/admin/settings/permissions/Index.vue";
import PetOverview from "@/views/admin/pets/overview/Index.vue";
import RegisterView from "@/views/auth/RegisterView.vue";
import SettingPetServicePrice from "@/views/admin/pets/services-price/Index.vue";
import SettingView from "@/views/admin/settings/SettingView.vue";
import RegisterPetView from "@/views/admin/pets/register-pets/Index.vue"
import CartPageView from "@/views/client/cart/Index.vue";
import CheckoutPage from "@/views/client/checkout/Index.vue"
import ProfilePage from "@/views/client/profile/Index.vue"
import i18n from "@/i18n";
import { env } from "@/config/env";
import { ADMIN_ROLES, canAccess } from "@/lib/access";
import { useAuthStore } from "@/stores";

/*
 *   RULE:
 *   meta key cần đối chiếu với pageMeta trong file i18n/locales/[lang].json
 *
 * */

const AUTH_PATH = ["login", "register"];

const router = createRouter({
  history: createWebHistory(env.publicPath),
  routes: [
    {
      path: "/",
      name: "home",
      component: HomeView,
      meta: {
        key: "home",
        layout: PAGE_LAYOUT.CLIENT,
      },
    },
    {
      path: "/login",
      name: "login",
      component: LoginView,
      meta: {
        key: "login",
        layout: PAGE_LAYOUT.AUTH,
      },
    },
    {
      path: "/register",
      name: "register",
      component: RegisterView,
      meta: {
        key: "register",
        layout: PAGE_LAYOUT.AUTH,
      },
    },
    {
      path: "/forgot-password",
      name: "forgotPw",
      component: ForgotPassView,
      meta: {
        key: "forgotPw",
        layout: PAGE_LAYOUT.AUTH,
      },
    },
    {
      path: "/contact",
      name: "contact",
      component: ContactView,
      meta: {
        key: "contact",
        layout: PAGE_LAYOUT.CLIENT,
      },
    },
    {
      path: "/about-us",
      name: "about-us",
      component: HomeView,
      meta: {
        key: "about-us",
        layout: PAGE_LAYOUT.CLIENT,
      },
    },
    {
      path: "/coupons",
      name: "coupons",
      component: HomeView,
      meta: {
        key: "coupons",
        layout: PAGE_LAYOUT.CLIENT,
      },
    },
    {
      path: "/products",
      name: "products",
      component: HomeView,
      meta: {
        key: "products",
        layout: PAGE_LAYOUT.CLIENT,
      },
    },
    {
      path: "/cart",
      name: "cart",
      component: CartPageView,
      meta: {
        key: "cart",
        layout: PAGE_LAYOUT.NO_LAYOUT,
      },
    },
    {
      path: "/checkout",
      name: "checkout",
      component: CheckoutPage,
      meta: {
        key: "checkout",
        layout: PAGE_LAYOUT.NO_LAYOUT,
      },
    },
    {
      path: "/profile",
      name: "profile",
      component: ProfilePage,
      meta: {
        key: "checkout",
        layout: PAGE_LAYOUT.CLIENT,
      },
    },
    {
      path: "/admin/",
      name: "admin",
      meta: {
        layout: PAGE_LAYOUT.ADMIN,
        requiresAuth: true,
        roles: ADMIN_ROLES,
      },
      children: [
        {
          path: "",
          name: "dashboard",
          component: DashboardView,
        },
        {
          path: "users",
          name: "users",
          component: ListUserView,
        },
        {
          path: "users-groups",
          name: "usersGroup",
          component: ListUserGroupView,
        },
        {
          path: "pets",
          children: [
            {
              path: "",
              name: "pets",
              component: ListPets,
              meta: {
                key: "pets",
              },
            },
            {
              path: "",
              name: "register-pets",
              component: RegisterPetView,
              meta: {
                key: "pets",
              },
            },
            {
              path: ":petId/setting-pet-service-price",
              name: "settingPetServicePrice",
              component: SettingPetServicePrice,
              meta: {
                key: "settingPetServicePrice",
              },
            },
            {
              path: ":petId/setting-pet-service-price/:serviceId",
              name: "DetailPetService",
              component: DetailPetServicePrice,
              meta: {
                key: "settingPetServicePrice",
              },
            },
            {
              path: "services",
              name: "petService",
              component: ListPetServices,
              meta: {
                key: "settingPetServicePrice",
              },
            },
            {
              path: "overview",
              name: "petOverview",
              component: PetOverview,
              meta: {
                key: "settingPetServicePrice",
              },
            },
            {
              path: "service-combos",
              name: "petServiceCombo",
              component: ComboServiceView,
              meta: {
                key: "settingPetServicePrice",
              },
            },
            // {
            //   path: "services-create",
            //   name: "petServiceCreate",
            //   component: CreatePetServices,
            //   meta: {
            //     key: "settingPetServicePrice",
            //   },
            // },
          ],
        },
        
        {
          path: "schedule",
          children: [
            {
              path: "list-order-schedule",
              name: "listOrderSchedule",
              component: ListScheduleOrder,
              meta: {
                key: "schedule",
              },
            },
            {
              path: "list-order-schedule/:id",
              name: "detailOrderScheduleDetail",
              component: DetailScheduleOrder,
              meta: {
                key: "schedule",
              },
            },
          ],
        },
        {
          path: "settings",
          children: [
            {
              path: "",
              name: "settings",
              component: SettingView,
              meta: {
                key: "pets",
              },
            },
            {
              path: "permissions",
              name: "permissions",
              component: PermissionView,
              meta: {
                key: "pets",
              },
            },
          ],
        },
      ],
    },
    {
      path: "/:pathMatch(.*)*",
      meta: {
        layout: PAGE_LAYOUT.NO_LAYOUT,
        requiresAuth: true,
      },
      component: NotFoundPage,
    },
  ],
});
router.afterEach((to, from) => {
  Vue.nextTick(() => {
    document.title = i18n.global.t(`pageMeta.${to.meta.key}`);
  });
});
router.beforeEach(async (to) => {
  const auth = useAuthStore();
  // Wait for the stored session to be restored, otherwise a page refresh would
  // look signed-out for a moment and bounce the user to the home page.
  await auth.init();

  const allowed = canAccess(
    { ...to.meta, guestOnly: AUTH_PATH.includes(to.meta.key as string) },
    { isAuthenticated: auth.isAuthenticated, role: auth.role }
  );
  return allowed ? true : { name: "home" };
});

export default router;
