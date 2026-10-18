import { useRequestHeaders, useRuntimeConfig } from "#imports";
import { apiUrl } from "@/utils/apiUrl";
import { createPublicApi } from "../publicApi";
import type { PublicApi, PublicGet } from "../types";

/**
 * The public catalog client. Call it in setup: it reads the API base (the deployed site in the app)
 * and, while rendering on the server, passes the visitor's IP on so the per-IP limit still applies.
 */
export const usePublicApi = (): PublicApi => {
  const base = useRuntimeConfig().public.apiBase as string | undefined;
  const headers = import.meta.server ? useRequestHeaders(["x-forwarded-for"]) : undefined;
  // The route's type comes from the API contract in shared/public-api/types.ts, not from Nitro's inference.
  const get: PublicGet = <T>(path: string, query?: Record<string, string | number | boolean | undefined>) =>
    $fetch<T>(apiUrl(base, `/api/public/${path}`), { query, headers }) as Promise<T>;
  return createPublicApi(get);
};
