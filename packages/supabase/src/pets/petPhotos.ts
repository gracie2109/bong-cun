// One profile photo per pet, kept in the public "pet-photos" bucket (see 20261024010000_pet_photos.sql).
// Files are named <pet id>/<uuid>.webp and never overwritten, so the long cache is safe.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { unwrap } from "@bongcun/supabase/shared";

type Client = SupabaseClient<Database>;

export const PET_PHOTO_BUCKET = "pet-photos";
export const MAX_PET_PHOTO_BYTES = 2 * 1024 * 1024;
export const PET_PHOTO_TYPES = ["image/webp", "image/jpeg", "image/png"];
const CACHE_SECONDS = "31536000";

/** Returns a message key when the file cannot be a pet photo, otherwise null. */
export const validatePetPhoto = (file: { type: string; size: number }): "type" | "size" | null => {
  if (!PET_PHOTO_TYPES.includes(file.type)) return "type";
  if (file.size > MAX_PET_PHOTO_BYTES) return "size";
  return null;
};

const extensionOf = (type: string): string => (type === "image/jpeg" ? "jpg" : type === "image/png" ? "png" : "webp");

/** Uploads the file under the pet's folder and returns its path and public URL. */
export const uploadPetPhoto = async (
  client: Client,
  petId: string,
  file: File
): Promise<{ path: string; url: string }> => {
  const path = `${petId}/${globalThis.crypto.randomUUID()}.${extensionOf(file.type)}`;
  const upload = await client.storage
    .from(PET_PHOTO_BUCKET)
    .upload(path, file, { contentType: file.type, cacheControl: CACHE_SECONDS, upsert: false });
  if (upload.error) throw upload.error;
  return { path, url: client.storage.from(PET_PHOTO_BUCKET).getPublicUrl(path).data.publicUrl };
};

const removeFile = async (client: Client, path: unknown): Promise<void> => {
  if (typeof path !== "string" || !path) return;
  // A file left behind is only wasted space, so a failed delete is not an error.
  await client.storage.from(PET_PHOTO_BUCKET).remove([path]).catch(() => undefined);
};

/** Uploads the file and makes it the pet's photo; if saving fails the new file is removed again. */
export const setPetPhoto = async (client: Client, petId: string, file: File): Promise<string> => {
  const { path, url } = await uploadPetPhoto(client, petId, file);
  const { data, error } = await client.rpc("set_pet_photo", { p_pet: petId, p_path: path, p_url: url });
  if (error) {
    await removeFile(client, path);
    throw error;
  }
  await removeFile(client, data);
  return url;
};

/** Clears the pet's photo and deletes the file. */
export const removePetPhoto = async (client: Client, petId: string): Promise<void> => {
  const old = unwrap(await client.rpc("set_pet_photo", { p_pet: petId, p_path: null, p_url: null }));
  await removeFile(client, old);
};
