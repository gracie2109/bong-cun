import { NAV_MATCH } from "@/config/shopNav";

/** Whether a header entry is the current page or one of its sub-pages (a product under "Sản phẩm"). */
export const isNavActive = (routeName: unknown, itemName: string): boolean => {
  const current = String(routeName ?? "");
  return (NAV_MATCH[itemName] ?? [itemName]).includes(current);
};
