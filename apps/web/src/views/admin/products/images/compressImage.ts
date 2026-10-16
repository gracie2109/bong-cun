/** Longest side of a stored picture, in pixels. */
export const MAX_EDGE = 1600;
const WEBP_QUALITY = 0.85;

/** Size that fits `width` x `height` inside `maxEdge` on the longer side; never scales up. */
export const fitWithin = (width: number, height: number, maxEdge = MAX_EDGE): { width: number; height: number } => {
  const scale = Math.min(1, maxEdge / Math.max(width, height));
  return { width: Math.max(1, Math.round(width * scale)), height: Math.max(1, Math.round(height * scale)) };
};

/** The file name with its extension replaced. */
export const renameExtension = (name: string, extension: string): string =>
  `${name.replace(/\.[^.]+$/, "") || "image"}.${extension}`;

/**
 * Scales a picture down to 1600px and re-encodes it as WebP in the browser. A GIF (it may be
 * animated) and anything the browser cannot decode or shrink come back unchanged.
 */
export const compressImage = async (file: File): Promise<File> => {
  if (file.type === "image/gif") return file;
  try {
    const bitmap = await createImageBitmap(file);
    const { width, height } = fitWithin(bitmap.width, bitmap.height);
    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    canvas.getContext("2d")?.drawImage(bitmap, 0, 0, width, height);
    bitmap.close();
    const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, "image/webp", WEBP_QUALITY));
    if (!blob || blob.type !== "image/webp" || blob.size >= file.size) return file;
    return new File([blob], renameExtension(file.name, "webp"), { type: "image/webp" });
  } catch {
    return file;
  }
};
