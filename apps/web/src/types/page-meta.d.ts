declare module "#app" {
  interface PageMeta {
    /** i18n key under `pageMeta.*`, used for the document title. */
    titleKey?: string;
    requiresAuth?: boolean;
    roles?: readonly string[];
    /** Any staff account (account type other than customer). */
    staffOnly?: boolean;
    /** Keep the page out of search results (e.g. placeholder pages that duplicate the home page). */
    noindex?: boolean;
    /** Stay mounted when only the query changes (filters kept in the URL), instead of re-mounting. */
    keepOnQuery?: boolean;
  }
}

export {};
