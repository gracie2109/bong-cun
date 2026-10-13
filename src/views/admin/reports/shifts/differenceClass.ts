/** Red when the drawer was short, amber when it was over, plain when it matches or is not counted. */
export const differenceClass = (difference: number | null): string => {
  if (difference === null || difference === 0) return "";
  return difference > 0 ? "text-amber-600" : "text-red-600";
};
