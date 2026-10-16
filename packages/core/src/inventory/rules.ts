/** Today in Vietnam as YYYY-MM-DD, the day the database judges expiry by. */
export const businessDate = (): string =>
  new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Ho_Chi_Minh" }).format(new Date());

export const isExpired = (expiryDate: string | null): boolean => !!expiryDate && expiryDate < businessDate();
