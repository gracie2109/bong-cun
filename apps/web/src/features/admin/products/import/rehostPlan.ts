import type { ImportRow } from "@bongcun/core/data-io";

/** True when the address is not one of the shop's own storage (`ownHost`), so it should be copied in. */
export const isExternalImage = (url: string, ownHost: string): boolean => {
  try {
    const parsed = new URL(url);
    return parsed.hostname !== ownHost;
  } catch {
    return false;
  }
};

/** Every outside picture address of the rows, once each, in the order they first appear. */
export const externalImageUrls = (rows: readonly ImportRow[], ownHost: string): string[] => {
  const urls = new Set<string>();
  for (const row of rows) {
    for (const url of row.images) {
      if (isExternalImage(url, ownHost)) urls.add(url);
    }
  }
  return [...urls];
};

/**
 * The rows with outside pictures replaced by their copies in the shop's storage (`copies`). An outside
 * picture that has no copy (the download failed) is dropped, so an import never keeps a link to
 * another site.
 */
export const swapImageUrls = (rows: readonly ImportRow[], ownHost: string, copies: ReadonlyMap<string, string>): ImportRow[] =>
  rows.map((row) => ({
    ...row,
    images: row.images.flatMap((url) => {
      if (!isExternalImage(url, ownHost)) return [url];
      const copy = copies.get(url);
      return copy ? [copy] : [];
    }),
  }));
