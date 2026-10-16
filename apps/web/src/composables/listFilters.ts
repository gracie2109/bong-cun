/** Equality for filter values: strings, numbers, booleans, and arrays of them (a date range). */
export const isSameFilterValue = (a: unknown, b: unknown): boolean => {
  if (Array.isArray(a) && Array.isArray(b)) return a.length === b.length && a.every((item, i) => isSameFilterValue(item, b[i]));
  return a === b;
};

/** How many filters differ from their default. */
export const countActiveFilters = <F extends Record<string, unknown>>(current: F, defaults: F): number =>
  Object.keys(defaults).filter((key) => !isSameFilterValue(current[key], defaults[key])).length;
