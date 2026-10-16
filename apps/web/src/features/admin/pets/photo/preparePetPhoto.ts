import { compressImage } from "@/lib/images/compressImage";
import { validatePetPhoto } from "@bongcun/supabase/pets";
import { PET_PHOTO_COMPRESSION } from "./petPhotoRules";

export type PreparedPhoto = { file: File; problem?: undefined } | { file?: undefined; problem: "type" | "size" };

/** Shrinks the chosen picture to 800px WebP and checks it fits the bucket's rules (type, 2 MB). */
export const preparePetPhoto = async (original: File): Promise<PreparedPhoto> => {
  const file = await compressImage(original, PET_PHOTO_COMPRESSION);
  const problem = validatePetPhoto(file);
  return problem ? { problem } : { file };
};

/** The message key for a photo that cannot be used. */
export const photoProblemKey = (problem: "type" | "size"): string =>
  `petCare.pets.photo.${problem === "type" ? "badType" : "tooBig"}`;
