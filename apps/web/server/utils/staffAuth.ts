import type { H3Event } from "h3";

/** The access token of a "Bearer <token>" header, or an empty string. */
export const bearerToken = (header: string | undefined): string => (header?.startsWith("Bearer ") ? header.slice(7).trim() : "");

/**
 * Lets only a signed-in person who may edit products through. The check is the database's own
 * `can_products('UPDATE')`, asked with the caller's token, so the roles stay defined in one place.
 */
export const requireProductEditor = async (event: H3Event): Promise<void> => {
  const token = bearerToken(getRequestHeader(event, "authorization"));
  const config = useRuntimeConfig(event).public.supabase as { url?: string; key?: string; publishableKey?: string } | undefined;
  const key = config?.key ?? config?.publishableKey;
  if (!token || !config?.url || !key) {
    throw createError({ statusCode: 401, statusMessage: "Sign in first" });
  }

  const allowed = await $fetch<boolean>(`${config.url}/rest/v1/rpc/can_products`, {
    method: "POST",
    headers: { apikey: key, Authorization: `Bearer ${token}` },
    body: { p_method: "UPDATE" },
  }).catch(() => false);
  if (allowed !== true) {
    throw createError({ statusCode: 403, statusMessage: "Not allowed to edit products" });
  }
};
