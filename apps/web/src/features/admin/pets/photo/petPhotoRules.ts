import type { CompressOptions } from "@/lib/images/compressImage";

/** Pet photos are shown at 160px at most, so 800px keeps them sharp on retina screens at 40-150 KB. */
export const PET_PHOTO_COMPRESSION: CompressOptions = { maxEdge: 800, quality: 0.82 };
