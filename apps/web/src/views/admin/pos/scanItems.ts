import { supabaseClient } from "@/lib/supabase";
import { getBranchPrices } from "@/repositories/branchPrices";
import { findByBarcode, getSellableProduct, searchSellableProducts } from "@bongcun/supabase/products";
import { priceAtBranch } from "./branchPricing";
import { toProductItem, type CatalogItem } from "./catalog";
import { itemInUnit } from "./unitPricing";

/** The item an exact barcode stands for, in the unit the code belongs to (a box code adds a box). */
export const itemForBarcode = async (code: string, branchId: string | undefined): Promise<CatalogItem | null> => {
  const client = supabaseClient();
  const hit = await findByBarcode(client, code, branchId);
  if (!hit) return null;
  const product = await getSellableProduct(client, hit.productId);
  if (!product) return null;
  const prices = branchId ? await getBranchPrices(client, branchId, [product.id]) : undefined;
  const item = toProductItem(priceAtBranch(product, prices));
  const unit = hit.unitId ? item.units?.find((candidate) => candidate.id === hit.unitId) ?? null : null;
  return itemInUnit(item, unit);
};

/** Products matching a typed code or name, at the price this branch sells them for. */
export const searchedItems = async (code: string, branchId: string | undefined): Promise<CatalogItem[]> => {
  const client = supabaseClient();
  const found = await searchSellableProducts(client, code);
  const prices = branchId ? await getBranchPrices(client, branchId, found.map((product) => product.id)) : undefined;
  return found.map((product) => toProductItem(priceAtBranch(product, prices)));
};
