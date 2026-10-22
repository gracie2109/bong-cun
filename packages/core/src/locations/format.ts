/** One address line for a two-level address: street, commune, province (empty parts are skipped). */
export const formatLocationLine = (street: string | null | undefined, ward: string | null | undefined, province: string | null | undefined): string =>
  [street, ward, province]
    .map((part) => part?.trim() ?? "")
    .filter((part) => part !== "")
    .join(", ");
