/** "2 years 3 months", "5 months" or "" when the birth date is unknown. Labels come from the caller. */
export const petAge = (birthDate: string, now = new Date()): { years: number; months: number } | null => {
  if (!birthDate) return null;
  const born = new Date(birthDate);
  if (Number.isNaN(born.getTime()) || born > now) return null;
  let months = (now.getFullYear() - born.getFullYear()) * 12 + (now.getMonth() - born.getMonth());
  if (now.getDate() < born.getDate()) months -= 1;
  months = Math.max(months, 0);
  return { years: Math.floor(months / 12), months: months % 12 };
};
