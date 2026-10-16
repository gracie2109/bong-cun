import { describe, expect, it } from "vitest";
import { MAX_PET_PHOTO_BYTES, validatePetPhoto } from "@bongcun/supabase/pets";
import { fitWithin, renameExtension } from "@/lib/images/compressImage";

describe("validatePetPhoto", () => {
  it("accepts webp, jpeg and png up to 2 MB", () => {
    expect(validatePetPhoto({ type: "image/webp", size: 1000 })).toBeNull();
    expect(validatePetPhoto({ type: "image/jpeg", size: MAX_PET_PHOTO_BYTES })).toBeNull();
    expect(validatePetPhoto({ type: "image/png", size: 1 })).toBeNull();
  });

  it("refuses other types and big files", () => {
    expect(validatePetPhoto({ type: "image/gif", size: 1000 })).toBe("type");
    expect(validatePetPhoto({ type: "application/pdf", size: 1000 })).toBe("type");
    expect(validatePetPhoto({ type: "image/webp", size: MAX_PET_PHOTO_BYTES + 1 })).toBe("size");
  });
});

describe("fitWithin", () => {
  it("shrinks the longer side to the limit and keeps the ratio", () => {
    expect(fitWithin(4000, 3000, 800)).toEqual({ width: 800, height: 600 });
    expect(fitWithin(3000, 4000, 800)).toEqual({ width: 600, height: 800 });
  });

  it("never scales up", () => {
    expect(fitWithin(500, 400, 800)).toEqual({ width: 500, height: 400 });
  });

  it("uses 1600 when no limit is given", () => {
    expect(fitWithin(3200, 1600)).toEqual({ width: 1600, height: 800 });
  });
});

describe("renameExtension", () => {
  it("swaps the extension", () => {
    expect(renameExtension("IMG_001.HEIC", "webp")).toBe("IMG_001.webp");
    expect(renameExtension("noext", "webp")).toBe("noext.webp");
  });
});
