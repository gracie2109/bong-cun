import type { H3Event } from "h3";

const GHN_API = "https://online-gateway.ghn.vn/shiip/public-api";

type GhnRequest = {
  method?: "GET" | "POST";
  query?: Record<string, string | number>;
  body?: Record<string, unknown>;
  headers?: Record<string, string>;
  /** Shipping-order endpoints identify the shop; master-data endpoints do not. */
  withShop?: boolean;
};

/**
 * Calls GHN with the server-only credentials (runtimeConfig.ghn, NUXT_GHN_*)
 * and returns GHN's JSON body (`{ code, message, data }`) untouched, error
 * responses included, so the client services keep their old handling.
 */
export const ghnFetch = (event: H3Event, path: string, request: GhnRequest = {}) => {
  const { ghn } = useRuntimeConfig(event);
  if (!ghn.token) {
    throw createError({ statusCode: 503, statusMessage: "GHN is not configured" });
  }
  if (request.withShop && !ghn.shopId) {
    throw createError({ statusCode: 503, statusMessage: "GHN shop is not configured" });
  }

  return $fetch(path, {
    baseURL: GHN_API,
    method: request.method ?? "GET",
    query: request.query,
    body: request.body,
    ignoreResponseError: true,
    headers: {
      "Content-Type": "application/json",
      Token: ghn.token,
      ...(request.withShop ? { ShopId: ghn.shopId } : {}),
      ...request.headers,
    },
  });
};
