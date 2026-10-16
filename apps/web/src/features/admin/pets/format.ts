import { format } from "date-fns";

export const initials = (name: string): string =>
  name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((word) => word.charAt(0).toUpperCase())
    .join("");

/** Whole years and remaining months since a birth date, or null when unknown or in the future. */
export const ageOf = (
  birthDate: string | null,
  now: Date = new Date()
): { years: number; months: number } | null => {
  if (!birthDate) return null;
  const born = new Date(birthDate);
  if (Number.isNaN(born.getTime())) return null;

  let months = (now.getFullYear() - born.getFullYear()) * 12 + now.getMonth() - born.getMonth();
  if (now.getDate() < born.getDate()) months -= 1;
  if (months < 0) return null;
  return { years: Math.floor(months / 12), months: months % 12 };
};

type Translate = (key: string, named?: Record<string, unknown>) => string;

/** Localized age like "2 tuổi 3 tháng", or the "unknown" label when there is no usable birth date. */
export const formatAge = (birthDate: string | null, t: Translate): string => {
  const age = ageOf(birthDate);
  if (!age) return t("petCare.pets.ageUnknown");
  if (age.years === 0) return t("petCare.pets.ageMonths", { m: age.months });
  return age.months === 0
    ? t("petCare.pets.ageYears", { y: age.years })
    : t("petCare.pets.ageYearsMonths", { y: age.years, m: age.months });
};

export const formatDate =(iso: string): string => format(new Date(iso), "dd/MM/yyyy");

export const formatShortDate = (iso: string): string => format(new Date(iso), "dd/MM");

/** Today as yyyy-MM-dd, the format of `<input type="date">`. */
export const todayInput = (): string => format(new Date(), "yyyy-MM-dd");
