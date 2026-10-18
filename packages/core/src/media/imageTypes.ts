// Picture formats the app accepts, kept in one place. Each upload area builds its list from these;
// the storage buckets carry the same lists (see the *_bucket / *_image_types migrations).

export const IMAGE_MIME = {
  jpeg: "image/jpeg",
  png: "image/png",
  webp: "image/webp",
  avif: "image/avif",
  gif: "image/gif",
} as const;

export type ImageMime = (typeof IMAGE_MIME)[keyof typeof IMAGE_MIME];

/** Still pictures every upload area takes: products, pet photos and medical attachments. */
export const PHOTO_TYPES: readonly ImageMime[] = [IMAGE_MIME.png, IMAGE_MIME.jpeg, IMAGE_MIME.webp, IMAGE_MIME.avif];

/** Product and other catalog pictures: the still formats plus GIF (it may be animated). */
export const CATALOG_IMAGE_TYPES: readonly ImageMime[] = [...PHOTO_TYPES, IMAGE_MIME.gif];

const EXTENSIONS: Record<ImageMime, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
  "image/avif": "avif",
  "image/gif": "gif",
};

/** The usual file extension of a picture type, or null when the type is not a known picture. */
export const imageExtension = (type: string): string | null => EXTENSIONS[type as ImageMime] ?? null;

/** The `accept` value of a file input for these types; picture extensions are added for pickers that ignore MIME types. */
export const acceptAttribute = (types: readonly string[]): string => {
  const extensions = types.flatMap((type) => {
    const extension = imageExtension(type);
    if (!extension) return [];
    return extension === "jpg" ? [".jpg", ".jpeg"] : [`.${extension}`];
  });
  return [...types, ...extensions].join(",");
};
