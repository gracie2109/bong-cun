import type { LinkProp } from "@/types";
import { Settings2 } from "lucide-vue-next";

export const ADMIN_NAVIGATOR: LinkProp[] = [
  {
    title: "customers",
    icon: "lucide:user-2",
    name: "users",
  },
  {
    title: "pets",
    icon: "lucide:paw-print",
    name: "pets",
    children: [
      {
        title: "Hồ sơ thú cưng",
        icon: "lucide:paw-print",
        name: "pets",
      },
      {
        title: "Danh mục loài",
        icon: "lucide:dog",
        name: "petSpecies",
      },
      {
        title: "Dịch vụ spa",
        icon: "carbon:settings-services",
        name: "petService",
      },
      {
        title: "Bảng giá",
        icon: "lucide:banknote",
        name: "petPrices",
      },
      {
        title: "Combo",
        icon: "lucide:layers-2",
        name: "petServiceCombo",
      },
    ],
  },
  {
    title: "schedule",
    icon: "lucide:calendar-days",
    name: "listOrderSchedule",
  },
  {
    title: "Vai trò & Phân quyền",
    icon: "lucide:shield-check",
    name: "settings",
    children: [
      {
        title: "Cấu hình vai trò",
        icon: "lucide:user-cog",
        name: "settings",
      },
      {
        title: "Danh sách quyền",
        icon: "lucide:key-round",
        name: "permissions",
      },
      {
        title: "Ma trận đối chiếu",
        icon: "lucide:grid-3x3",
        name: "permissionMatrix",
      },
    ],
  },
];

export const PROFILE_KEYS = {
  GENERAL: "general",
  ADDRESS: 'address',
  TRANSACTION: 'transactions'

}
export const navigation = {
  profileNav: [
    {
      path: "general",
      key: PROFILE_KEYS.GENERAL,
      label: "general",
      icon: "",
    },
    {
      path: "address",
      key:  PROFILE_KEYS.ADDRESS,
      icon: "",
      label: "address",
    },
    {
      path: "transactions",
      key: PROFILE_KEYS.TRANSACTION,
      label: "transactions",
      icon: "",
    },
  ],
  clientNav: [
    {
      text: "Home",
      name: "home",
    },
    {
      text: "About Us",
      name: "about-us",
    },
    {
      text: "Contact",
      name: "contact",
    },
    {
      text: "Products",
      name: "products",
      type: "multi",
    },
    {
      text: "Coupons",
      name: "coupons",
    },
  ],
};
