import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";
import { CalendarDateTime } from "@internationalized/date";
import type { RestfullMethod, ResponseStatus } from "@/types";
import { toast } from "vue-sonner";
import i18n from "@/i18n";
import type { Updater } from "@tanstack/vue-table";
import type { Ref } from "vue";
import { format } from "date-fns";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function getCurrentDateTime() {
  const now = new Date();
  const day = now.getDate();
  const month = now.getMonth() + 1;
  const year = now.getFullYear();
  const hours = now.getHours();
  const minutes = now.getMinutes();
  const seconds = now.getSeconds();
  return new CalendarDateTime(year, month, day, hours, minutes, seconds);
}

export function sendMessageToast(
  status: ResponseStatus,
  method: RestfullMethod,
  toastType: "success" | "error" | "default",
  message?: string
) {
  if (!(status || method || toastType)) return;

  if (toastType === "success")
    return toast.success(
      i18n.global.t(`common.success`, {
        action: i18n.global.t(`common.${method}`),
      })
    );
  else if (toastType === "error")
    return toast.error(
      i18n.global.t("common.fail", {
        action: i18n.global.t(`common.${method}`),
        mess: message,
      })
    );
  else
    toast(
      i18n.global.t(`common.${status}`, {
        action: i18n.global.t(`common.${method}`),
      })
    );
}

export function setLocalStorage(key: string, data: any) {
  if (!key) return;
  localStorage.setItem(key, JSON.stringify(data));
}

export function getLocalStorage(key: string) {
  if (!key) return;
  return JSON.parse(JSON.stringify(localStorage.getItem(key)));
}

export function removeStorage(keysToKeep: string[]): void {
  const savedItems: { [key: string]: string } = {};

  keysToKeep.forEach((key) => {
    const value = localStorage.getItem(key);
    if (value !== null) {
      savedItems[key] = value;
    }
  });

  localStorage.clear();
  Object.keys(savedItems).forEach((key) => {
    localStorage.setItem(key, savedItems[key]);
  });
}

export function truncateText(text: string, maxLength: number) {
  const newText = text.slice(0, maxLength);
  return text.length > maxLength ? `${newText}...` : newText;
}

export function formatPrice(price: number | string) {
  if (price == "undefined" || price === "") return;
  return new Intl.NumberFormat("vi-VN", {
    style: "currency",
    currency: "VND",
    notation: "standard",
  }).format(Number(price));
}

export function valueUpdater<T extends Updater<any>>(
  updaterOrValue: T,
  ref: Ref
) {
  ref.value =
    typeof updaterOrValue === "function"
      ? updaterOrValue(ref.value)
      : updaterOrValue;
}

export function formatDateTime(date: string | Date | number) {
  if (!date) return;
  return format(date, "dd-MM-yyyy HH:mm:ss");
}

export function convertNumberToTime(minutes: number) {
  const days = Math.floor(minutes / 1440);
  const hours = Math.floor((minutes % 1440) / 60);
  const mins = minutes % 60;

  if (days > 0) {
    return `${days}d ${hours}:${mins.toString().padStart(2, "0")}`;
  } else {
    return `${hours}:${mins.toString().padStart(2, "0")}`;
  }
}

export const getIndex = ({
  dataPage,
  index,
}: {
  index: number;
  dataPage: { page: number; page_size: number };
}) => {
  const stt = (dataPage.page - 1) * dataPage.page_size + index + 1;
  return stt;
};

export const reduceData = (data: any) => {
  return data.reduce((acc: any, curr: any) => {
    acc[curr] = (acc[curr] || 0) + 1;
    return acc;
  }, {});
};


export function getUniquePermissions(array1: any, array2: any) {
  if (!(array1 && array2)) return [];
  const setA = new Set(array1?.map((item: any) => item?.id));
  return array2?.filter((item: any) => {
    if (!setA.has(item?.id)) {
      setA.add(item?.name);
      return item;
    }
  });
}

export function matchingTwoObject(obj1: any, ob2: any): any[] {
  if (!(obj1 || ob2)) return [];
  else {
    const matchingKeys = [];
    const keys1 = Object.keys(obj1);
    const keys2 = Object.keys(ob2);

    for (const key of keys1) {
      if (keys2.includes(key) && obj1[key] === ob2[key]) {
        matchingKeys.push(key);
      }
    }
    return matchingKeys;
  }
}
export const getQuantityOfPermission = (data: any[]) => {
  if (!data) return null;
  const dataname = data?.map((i) => i.name?.split(".")?.at(-1));
  return dataname.reduce((acc, curr) => {
    acc[curr] = (acc[curr] || 0) + 1;
    return acc;
  }, {});
};
