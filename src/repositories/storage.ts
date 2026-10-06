// Image uploads. Pure TS: takes a client, no Vue/Pinia/env.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";

type Client = SupabaseClient<Database>;

export const IMAGE_BUCKET = "images";
export const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
export const ALLOWED_IMAGE_TYPES = ["image/png", "image/jpeg", "image/webp", "image/gif"];

/** Returns a message when the file cannot be uploaded, otherwise null. */
export const validateImage = (file: { type: string; size: number }): string | null => {
  if (!ALLOWED_IMAGE_TYPES.includes(file.type)) return "Only PNG, JPEG, WebP or GIF images are allowed.";
  if (file.size > MAX_IMAGE_BYTES) return "The image must be 5 MB or smaller.";
  return null;
};

/**
 * Uploads into `<userId>/<folder>/`. The first path segment must be the caller's
 * own id: that is what the storage policy checks.
 */
export const uploadImage = async (
  client: Client,
  args: { userId: string; folder: string; file: File }
): Promise<{ path: string; url: string }> => {
  const safeName = args.file.name.replace(/[^a-zA-Z0-9._-]/g, "_");
  const path = `${args.userId}/${args.folder}/${globalThis.crypto.randomUUID()}-${safeName}`;

  const { error } = await client.storage
    .from(IMAGE_BUCKET)
    .upload(path, args.file, { contentType: args.file.type, upsert: false });
  if (error) throw error;

  return { path, url: client.storage.from(IMAGE_BUCKET).getPublicUrl(path).data.publicUrl };
};

/** Recovers the object path from a public URL produced by uploadImage(). */
export const pathFromPublicUrl = (url: string): string | null => {
  const marker = `/storage/v1/object/public/${IMAGE_BUCKET}/`;
  const index = url.indexOf(marker);
  if (index === -1) return null;
  return decodeURIComponent(url.slice(index + marker.length).split("?")[0]);
};

export const deleteImage = async (client: Client, path: string): Promise<void> => {
  const { error } = await client.storage.from(IMAGE_BUCKET).remove([path]);
  if (error) throw error;
};
