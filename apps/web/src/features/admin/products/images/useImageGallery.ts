import { ref, type Ref } from "vue";
import { supabaseClient } from "@/lib/supabase";
import type { ProductImage } from "@bongcun/supabase/products";
import { MAX_GROUP_IMAGES } from "@bongcun/supabase/products";
import { uploadCatalogImage, validateImage } from "@bongcun/supabase/storage";
import { compressImage } from "./compressImage";

export type GalleryImage = { key: string; url: string; storagePath: string | null };

let nextKey = 0;
const toGalleryImage = (url: string, storagePath: string | null): GalleryImage => ({
  key: `image-${nextKey++}`,
  url,
  storagePath,
});

/** Moves one item of a list to another place; out-of-range or unchanged moves return the list as is. */
export const moveItem = <T>(list: readonly T[], from: number, to: number): T[] => {
  if (from === to || from < 0 || to < 0 || from >= list.length || to >= list.length) return [...list];
  const next = [...list];
  const [item] = next.splice(from, 1);
  next.splice(to, 0, item as T);
  return next;
};

/**
 * The picture list of a product group being edited: add (compressed and uploaded to the shared
 * `catalog/` area), remove, reorder, choose the cover. The first picture is the cover.
 * `folder` names the sub-folder uploads go to.
 */
export const useImageGallery = (folder: Ref<string>) => {
  const images = ref<GalleryImage[]>([]);
  const uploading = ref(false);
  const error = ref("");
  // Files of the pictures the group had when the form opened, and of those uploaded since:
  // whatever is no longer in the list afterwards is deleted once the group is saved.
  let knownPaths = new Set<string>();

  const fill = (list: readonly ProductImage[]) => {
    images.value = list.map((image) => toGalleryImage(image.url, image.storagePath));
    knownPaths = new Set(list.flatMap((image) => (image.storagePath ? [image.storagePath] : [])));
    error.value = "";
  };

  const add = async (files: readonly File[]) => {
    error.value = "";
    const room = MAX_GROUP_IMAGES - images.value.length;
    if (files.length > room) error.value = `max:${MAX_GROUP_IMAGES}`;
    uploading.value = true;
    try {
      for (const original of files.slice(0, Math.max(room, 0))) {
        const invalid = validateImage(original);
        if (invalid) {
          error.value = invalid;
          continue;
        }
        const file = await compressImage(original);
        const { path, url } = await uploadCatalogImage(supabaseClient(), { folder: folder.value, file });
        knownPaths.add(path);
        images.value = [...images.value, toGalleryImage(url, path)];
      }
    } catch (failure) {
      error.value = (failure as { message?: string } | null)?.message ?? "Upload failed.";
    } finally {
      uploading.value = false;
    }
  };

  const remove = (index: number) => {
    images.value = images.value.filter((_, position) => position !== index);
  };

  const move = (from: number, to: number) => {
    images.value = moveItem(images.value, from, to);
  };

  const makeCover = (index: number) => move(index, 0);

  /** Files that were part of the gallery and no longer are; to delete after a successful save. */
  const removedPaths = (): string[] => {
    const kept = new Set(images.value.flatMap((image) => (image.storagePath ? [image.storagePath] : [])));
    return [...knownPaths].filter((path) => !kept.has(path));
  };

  return { images, uploading, error, fill, add, remove, move, makeCover, removedPaths };
};
