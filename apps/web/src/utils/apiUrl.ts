/** Joins the server base (empty on the website, the Vercel URL in the app) with an `/api/...` path. */
export const apiUrl = (base: string | undefined, path: string): string => {
  const root = (base ?? "").replace(/\/+$/, "");
  return `${root}/${path.replace(/^\/+/, "")}`;
};
