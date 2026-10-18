import { CATALOG_IMAGE_TYPES } from "@bongcun/core/media";

// Pictures the admin may pull into the shop's own storage through /api/admin/image-proxy.
// Only plain https addresses on these hosts are fetched (no other host, port or credentials).
export const IMAGE_PROXY_HOSTS = ["fexafkqzpbzjcupvbfhe.supabase.co", "auth.paddy.vn", "cdn.shopify.com"] as const;

export const IMAGE_PROXY_TYPES: readonly string[] = CATALOG_IMAGE_TYPES;
export const IMAGE_PROXY_MAX_BYTES = 5 * 1024 * 1024;
export const IMAGE_PROXY_TIMEOUT_MS = 15_000;

/** The URL when it is a plain https address on an allowed host, otherwise null. */
export const parseProxyImageUrl = (raw: string): URL | null => {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    return null;
  }
  const hasLogin = /^https:\/\/[^/?#]*@/.test(url.href);
  if (url.protocol !== "https:" || hasLogin || url.host !== url.hostname) return null;
  return (IMAGE_PROXY_HOSTS as readonly string[]).includes(url.hostname) ? url : null;
};

/** The media type of a response, without parameters; null when it is not an allowed picture type. */
export const proxyImageType = (contentType: string | null): string | null => {
  const type = contentType?.split(";")[0]?.trim().toLowerCase() ?? "";
  return IMAGE_PROXY_TYPES.includes(type) ? type : null;
};

/** Reads a body up to `maxBytes`; null when it is bigger (the rest is not downloaded). */
export const readCapped = async (response: Response, maxBytes: number): Promise<Uint8Array | null> => {
  const declared = Number(response.headers.get("content-length"));
  if (Number.isFinite(declared) && declared > maxBytes) return null;
  const reader = response.body?.getReader();
  if (!reader) return null;

  const chunks: Uint8Array[] = [];
  let size = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > maxBytes) {
      await reader.cancel();
      return null;
    }
    chunks.push(value);
  }

  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return bytes;
};
