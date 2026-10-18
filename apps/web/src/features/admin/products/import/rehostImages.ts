import { toast } from "vue-sonner";
import type { ImportRow } from "@bongcun/core/data-io";
import { uploadCatalogImage } from "@bongcun/supabase/storage";
import { supabaseClient } from "@/lib/supabase";
import { compressImage } from "@/lib/images/compressImage";
import { externalImageUrls, swapImageUrls } from "./rehostPlan";

const PROXY_PATH = "/api/admin/image-proxy";
const UPLOAD_FOLDER = "imported";
const CONCURRENCY = 4;

const fileNameOf = (url: string): string => decodeURIComponent(new URL(url).pathname.split("/").pop() || "image");

/** Downloads one picture through the server (the other site does not allow browsers to read it). */
const download = async (url: string, token: string): Promise<File> => {
  const response = await fetch(`${PROXY_PATH}?url=${encodeURIComponent(url)}`, { headers: { Authorization: `Bearer ${token}` } });
  if (!response.ok) throw new Error(`Image download failed (${response.status})`);
  const blob = await response.blob();
  return new File([blob], fileNameOf(url), { type: blob.type });
};

/** Runs `task` over `items` with a few at a time; a failure of one item never stops the others. */
const eachLimited = async <T>(items: readonly T[], limit: number, task: (item: T) => Promise<void>): Promise<void> => {
  let next = 0;
  const worker = async () => {
    while (next < items.length) {
      const item = items[next++] as T;
      await task(item);
    }
  };
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
};

/**
 * Copies the pictures of import rows that live on another site into the shop's own storage
 * (compressed to WebP, under `catalog/imported/`) and points the rows at the copies. Pictures already
 * in the shop's storage are left alone; one that cannot be copied is dropped and counted in a warning.
 * Copies are remembered, so a picture shared by several batches is uploaded once.
 */
export const createImageRehoster = () => {
  const client = supabaseClient();
  const ownHost = new URL(useRuntimeConfig().public.supabase.url).hostname;
  const copies = new Map<string, string>();
  const failed = new Set<string>();

  const apply = async (rows: ImportRow[]): Promise<ImportRow[]> => {
    const pending = externalImageUrls(rows, ownHost).filter((url) => !copies.has(url) && !failed.has(url));
    if (pending.length > 0) {
      const { data } = await client.auth.getSession();
      const token = data.session?.access_token ?? "";
      await eachLimited(pending, CONCURRENCY, async (url) => {
        try {
          const file = await compressImage(await download(url, token));
          const { url: copy } = await uploadCatalogImage(client, { folder: UPLOAD_FOLDER, file });
          copies.set(url, copy);
        } catch (error) {
          console.error("Could not copy the image", url, error);
          failed.add(url);
        }
      });
    }
    return swapImageUrls(rows, ownHost, copies);
  };

  /** Shows one warning for all pictures that could not be copied. */
  const reportFailures = () => {
    if (failed.size > 0) toast.warning(`${failed.size} ảnh không tải về được và đã bị bỏ qua.`);
  };

  return { apply, reportFailures };
};
