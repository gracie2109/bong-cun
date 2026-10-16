import type { SpaCatalog, SpaCombo, SpaService, SpaSpecies } from "@/types/spaCatalog";

/** One price line of a service for a species: a weight bracket (or "all weights") and its price. */
export type PriceLine = { key: string; label: string | null; price: number };

export const servicesForSpecies = (catalog: SpaCatalog, speciesId: string): SpaService[] =>
  catalog.services.filter((service) => service.speciesIds.includes(speciesId));

export const combosForSpecies = (catalog: SpaCatalog, speciesId: string): SpaCombo[] =>
  catalog.combos.filter((combo) => combo.speciesIds.includes(speciesId));

/**
 * The prices a customer sees for one service and species. A general-price service has one line
 * without a label; a by-weight one has a line per bracket that is priced, in weight order.
 */
export const priceLines = (service: SpaService, species: SpaSpecies): PriceLine[] => {
  if (service.type === "all") {
    return service.generalPrice === null ? [] : [{ key: "all", label: null, price: service.generalPrice }];
  }
  return species.brackets.flatMap((bracket) => {
    const found = service.prices.find((item) => item.speciesId === species.id && item.bracketId === bracket.id);
    return found ? [{ key: bracket.id, label: bracket.label, price: found.price }] : [];
  });
};

/** Species that have at least one service or combo, so an empty tab is never shown. */
export const speciesWithOffers = (catalog: SpaCatalog): SpaSpecies[] =>
  catalog.species.filter(
    (species) => servicesForSpecies(catalog, species.id).length > 0 || combosForSpecies(catalog, species.id).length > 0
  );

/** 90 -> { hours: 1, minutes: 30 }; null when the duration is unknown or zero. */
export const splitDuration = (totalMinutes: number | null): { hours: number; minutes: number } | null =>
  totalMinutes && totalMinutes > 0 ? { hours: Math.floor(totalMinutes / 60), minutes: totalMinutes % 60 } : null;

/** The percentage saved by a combo, or 0 when it has no higher original price. */
export const comboSavingPercent = (combo: SpaCombo): number =>
  combo.price !== null && combo.originPrice !== null && combo.originPrice > combo.price
    ? Math.round(((combo.originPrice - combo.price) / combo.originPrice) * 100)
    : 0;

/** The lowest price of a service for one species, or null when it has none yet ("from 120.000đ"). */
export const lowestPrice = (service: SpaService, species: SpaSpecies): number | null => {
  const prices = priceLines(service, species).map((line) => line.price);
  return prices.length > 0 ? Math.min(...prices) : null;
};
