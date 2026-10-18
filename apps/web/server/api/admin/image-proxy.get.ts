import { z } from "zod";
import {
  IMAGE_PROXY_MAX_BYTES,
  IMAGE_PROXY_TIMEOUT_MS,
  parseProxyImageUrl,
  proxyImageType,
  readCapped,
} from "../../utils/imageProxy";
import { requireProductEditor } from "../../utils/staffAuth";

const querySchema = z.object({ url: z.string().max(2048) });

// Hands a picture from an allowed outside host to the admin's browser, which compresses it and
// uploads it to the shop's own storage (the product import uses this to keep images in our bucket).
export default defineEventHandler(async (event) => {
  await requireProductEditor(event);

  const { url: raw } = await getValidatedQuery(event, querySchema.parse);
  const url = parseProxyImageUrl(raw);
  if (!url) throw createError({ statusCode: 400, statusMessage: "This image host is not allowed" });

  const response = await fetch(url, {
    redirect: "error",
    headers: { accept: "image/*" },
    signal: AbortSignal.timeout(IMAGE_PROXY_TIMEOUT_MS),
  }).catch(() => null);
  if (!response?.ok) throw createError({ statusCode: 502, statusMessage: "Could not download the image" });

  const type = proxyImageType(response.headers.get("content-type"));
  if (!type) throw createError({ statusCode: 415, statusMessage: "Not a supported image" });

  const bytes = await readCapped(response, IMAGE_PROXY_MAX_BYTES);
  if (!bytes) throw createError({ statusCode: 413, statusMessage: "The image is bigger than 5 MB" });

  setResponseHeaders(event, { "Content-Type": type, "Cache-Control": "private, max-age=3600" });
  return Buffer.from(bytes);
});
