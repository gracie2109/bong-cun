import type { ProductUnit } from "@/repositories/products";
import type { CatalogItem } from "./catalog";

/** What the database charges for a unit: its own price, else the base price times the factor. */
export const unitPrice = (basePrice: number, unit: ProductUnit): number =>
  unit.price ?? Math.round(basePrice * unit.factor * 100) / 100;

/** The same product sold in `unit`; null means its base unit again. */
export const itemInUnit = (item: CatalogItem, unit: ProductUnit | null): CatalogItem => {
  const basePrice = item.basePrice ?? item.price ?? 0;
  if (!unit) {
    return {
      ...item,
      unitId: null,
      factor: 1,
      unit: item.baseUnit ?? item.unit,
      price: basePrice,
      generalPrice: item.baseGeneralPrice,
    };
  }
  return {
    ...item,
    unitId: unit.id,
    factor: unit.factor,
    unit: unit.name,
    price: unitPrice(basePrice, unit),
    generalPrice: undefined,
  };
};

/** "3 hộp" for the whole units of `unit` in `baseQty` base units; empty when fewer than one fits. */
export const wholeUnits = (baseQty: number, unit: ProductUnit): string => {
  const count = Math.floor(baseQty / unit.factor);
  return count > 0 ? `${count} ${unit.name}` : "";
};
