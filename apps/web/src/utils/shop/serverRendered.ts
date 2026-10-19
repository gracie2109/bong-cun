// Public shop pages that are rendered on the server. Moving between them loads a fresh document
// (see plugins/server-navigation.client.ts), so their data arrives in the HTML and the browser
// makes no data requests of its own.
const SERVER_RENDERED_PREFIXES = ["/products"] as const;
const SERVER_RENDERED_PATHS = ["/", "/spa", "/boarding", "/about-us", "/contact"] as const;

/** Whether the server renders this path with its data (cart, checkout, booking and account stay client-side). */
export const isServerRenderedPath = (path: string): boolean =>
  (SERVER_RENDERED_PATHS as readonly string[]).includes(path) ||
  SERVER_RENDERED_PREFIXES.some((prefix) => path === prefix || path.startsWith(`${prefix}/`));

const CATALOG_PATH = "/products";
const pathOf = (url: string): string => url.split(/[?#]/)[0] ?? url;
const withoutHash = (url: string): string => url.split("#")[0] ?? url;

/**
 * A move that should reload the page: it lands on a server-rendered page at another path, or it
 * changes the search, filters, sort or page of the product list (those are in the URL query, so the
 * server renders the new list). A hash change, or a query change on any other page, stays in the browser.
 */
export const needsDocumentLoad = (fromUrl: string, toUrl: string): boolean => {
  const toPath = pathOf(toUrl);
  if (!isServerRenderedPath(toPath)) return false;
  if (pathOf(fromUrl) !== toPath) return true;
  return toPath === CATALOG_PATH && withoutHash(fromUrl) !== withoutHash(toUrl);
};
