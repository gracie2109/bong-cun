import { describe, expect, it } from "vitest";
import { CATALOG_IMAGE_TYPES, PHOTO_TYPES, acceptAttribute, imageExtension } from "@bongcun/core/media";
import { MAX_IMAGE_BYTES, validateImage } from "@bongcun/supabase/storage";
import { MAX_ATTACHMENT_BYTES, validateAttachment } from "@bongcun/supabase/medical";
import { MAX_PET_PHOTO_BYTES, validatePetPhoto } from "@bongcun/supabase/pets";
import { proxyImageType } from "../../server/utils/imageProxy";

describe("shared picture types", () => {
  it("lists AVIF beside the formats that were already allowed", () => {
    expect(PHOTO_TYPES).toEqual(["image/png", "image/jpeg", "image/webp", "image/avif"]);
    expect(CATALOG_IMAGE_TYPES).toEqual([...PHOTO_TYPES, "image/gif"]);
  });

  it("knows the extension of each picture type", () => {
    expect(imageExtension("image/avif")).toBe("avif");
    expect(imageExtension("image/jpeg")).toBe("jpg");
    expect(imageExtension("image/webp")).toBe("webp");
    expect(imageExtension("application/pdf")).toBeNull();
  });

  it("builds a file input accept value with MIME types and extensions", () => {
    expect(acceptAttribute(["image/avif", "image/jpeg", "application/pdf"])).toBe(
      "image/avif,image/jpeg,application/pdf,.avif,.jpg,.jpeg"
    );
  });
});

describe("validateImage (product and catalog pictures)", () => {
  it("accepts AVIF up to 5 MB and still takes PNG, JPEG, WebP and GIF", () => {
    expect(validateImage({ type: "image/avif", size: MAX_IMAGE_BYTES })).toBeNull();
    for (const type of ["image/png", "image/jpeg", "image/webp", "image/gif"]) {
      expect(validateImage({ type, size: 1000 }), type).toBeNull();
    }
  });

  it("refuses an AVIF over the limit and types that are not pictures", () => {
    expect(validateImage({ type: "image/avif", size: MAX_IMAGE_BYTES + 1 })).toMatch(/5 MB/);
    expect(validateImage({ type: "image/heic", size: 1000 })).toMatch(/AVIF/);
    expect(validateImage({ type: "", size: 1000 })).not.toBeNull();
    expect(validateImage({ type: "text/html", size: 1000 })).not.toBeNull();
  });
});

describe("validatePetPhoto with AVIF", () => {
  it("accepts AVIF up to 2 MB and refuses a bigger one", () => {
    expect(validatePetPhoto({ type: "image/avif", size: MAX_PET_PHOTO_BYTES })).toBeNull();
    expect(validatePetPhoto({ type: "image/avif", size: MAX_PET_PHOTO_BYTES + 1 })).toBe("size");
  });
});

describe("validateAttachment (medical files)", () => {
  it("accepts AVIF up to 10 MB beside PNG, JPEG, WebP and PDF", () => {
    expect(validateAttachment({ type: "image/avif", size: MAX_ATTACHMENT_BYTES })).toBeNull();
    for (const type of ["image/png", "image/jpeg", "image/webp", "application/pdf"]) {
      expect(validateAttachment({ type, size: 1000 }), type).toBeNull();
    }
  });

  it("refuses an AVIF over the limit and GIF (never allowed here)", () => {
    expect(validateAttachment({ type: "image/avif", size: MAX_ATTACHMENT_BYTES + 1 })).toBe("size");
    expect(validateAttachment({ type: "image/gif", size: 1000 })).toBe("type");
  });
});

describe("proxyImageType with AVIF", () => {
  it("lets AVIF through the import image proxy", () => {
    expect(proxyImageType("image/avif")).toBe("image/avif");
    expect(proxyImageType("image/svg+xml")).toBeNull();
  });
});
