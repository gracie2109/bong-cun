// Public shop pages that are rendered on the server. Moving between them loads a fresh document
// (see plugins/server-navigation.client.ts), so their data arrives in the HTML and the browser
// makes no data requests of its own.
const SERVER_RENDERED_PREFIXES = ["/products"] as const;
const SERVER_RENDERED_PATHS = ["/", "/spa", "/boarding", "/about-us", "/contact"] as const;

/** Whether the server renders this path with its data (cart, checkout, booking and account stay client-side). */
export const isServerRenderedPath = (path: string): boolean =>
  (SERVER_RENDERED_PATHS as readonly string[]).includes(path) ||
  SERVER_RENDERED_PREFIXES.some((prefix) => path === prefix || path.startsWith(`${prefix}/`));

/**
 * A move that should reload the page: it lands on a server-rendered page at another path.
 * Changes to the query or hash of the same page (search, filters, "load more") stay in the browser.
 */
export const needsDocumentLoad = (fromPath: string, toPath: string): boolean =>
  fromPath !== toPath && isServerRenderedPath(toPath);
