const pad = (value: number): string => String(value).padStart(2, "0");

/** Lower-case ASCII slug: "Hóa đơn" becomes "hoa-don". */
export const slugify = (text: string): string =>
  text
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/đ/gi, "d")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");

/** `<screen>-<yyyymmdd-hhmm>`, for example hoa-don-20261014-0910. */
export const exportFileBase = (name: string, now = new Date()): string =>
  `${slugify(name)}-${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}-${pad(now.getHours())}${pad(now.getMinutes())}`;
