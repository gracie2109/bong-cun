declare module "#app" {
  interface PageMeta {
    /** i18n key under `pageMeta.*`, used for the document title. */
    titleKey?: string;
    requiresAuth?: boolean;
    roles?: readonly string[];
    /** Keep the page out of search results (e.g. placeholder pages that duplicate the home page). */
    noindex?: boolean;
  }
}

export {};
