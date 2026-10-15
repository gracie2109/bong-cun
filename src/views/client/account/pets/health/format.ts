/** yyyy-MM-dd to dd/MM/yyyy; anything else is shown as it is. */
export const formatDay = (value: string): string => {
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(value);
  return match ? `${match[3]}/${match[2]}/${match[1]}` : value;
};
