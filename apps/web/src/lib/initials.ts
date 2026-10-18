/** First letters of the first two words of a name, upper-cased ("Nguyễn An" -> "NA"). */
export const initialsOf = (name: string): string =>
  name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((word) => word.charAt(0).toUpperCase())
    .join("");
