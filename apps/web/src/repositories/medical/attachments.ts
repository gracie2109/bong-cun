// Files attached to a visit, kept in the private "medical" bucket (see 20261021070300_medical_attachments.sql).
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { ATTACHMENT_KINDS, type AttachmentKind, type MedicalAttachment } from "@bongcun/core/medical";
import { unwrap } from "@bongcun/supabase/shared";
import { asRecord, str, strOrNull } from "@bongcun/supabase/shared";

type Client = SupabaseClient<Database>;

export const MEDICAL_BUCKET = "medical";
export const MAX_ATTACHMENT_BYTES = 10 * 1024 * 1024;
export const ALLOWED_ATTACHMENT_TYPES = ["image/png", "image/jpeg", "image/webp", "application/pdf"];
const SIGNED_URL_SECONDS = 600;

/** Returns a message key when the file cannot be attached, otherwise null. */
export const validateAttachment = (file: { type: string; size: number }): "type" | "size" | null => {
  if (!ALLOWED_ATTACHMENT_TYPES.includes(file.type)) return "type";
  if (file.size > MAX_ATTACHMENT_BYTES) return "size";
  return null;
};

export const listMedicalAttachments = async (client: Client, visitId: string): Promise<MedicalAttachment[]> => {
  const rows = unwrap(await client.rpc("list_medical_attachments", { p_visit: visitId }));
  return (Array.isArray(rows) ? rows : []).map((raw) => {
    const row = asRecord(raw);
    return {
      id: str(row.id),
      visitId: str(row.visit_id),
      kind: ATTACHMENT_KINDS.find((kind) => kind === row.kind) ?? "other",
      title: str(row.title),
      filePath: str(row.file_path),
      mimeType: str(row.mime_type),
      sizeBytes: Number(row.size_bytes ?? 0),
      createdByName: strOrNull(row.created_by_name),
      createdAt: str(row.created_at),
    };
  });
};

export type AttachmentInput = { petId: string; visitId: string; kind: AttachmentKind; title: string; file: File };

/** Uploads the file, then registers it; if registering fails the file is removed again. */
export const addMedicalAttachment = async (client: Client, input: AttachmentInput): Promise<string> => {
  const extension = input.file.name.includes(".") ? input.file.name.split(".").pop()!.replace(/[^a-zA-Z0-9]/g, "").slice(0, 8) : "bin";
  const path = `${input.petId}/${input.visitId}/${globalThis.crypto.randomUUID()}.${extension}`;
  const upload = await client.storage.from(MEDICAL_BUCKET).upload(path, input.file, { contentType: input.file.type, upsert: false });
  if (upload.error) throw upload.error;
  const { data, error } = await client.rpc("add_medical_attachment", {
    p_visit: input.visitId,
    p: { kind: input.kind, title: input.title, file_path: path, mime_type: input.file.type, size_bytes: input.file.size },
  });
  if (error) {
    await client.storage.from(MEDICAL_BUCKET).remove([path]);
    throw error;
  }
  return String(data);
};

export const removeMedicalAttachment = async (client: Client, id: string): Promise<void> => {
  const path = unwrap(await client.rpc("remove_medical_attachment", { p_id: id }));
  if (typeof path === "string") await client.storage.from(MEDICAL_BUCKET).remove([path]);
};

/** A link that works for ten minutes. */
export const signedAttachmentUrl = async (client: Client, path: string): Promise<string> => {
  const { data, error } = await client.storage.from(MEDICAL_BUCKET).createSignedUrl(path, SIGNED_URL_SECONDS);
  if (error) throw error;
  return data.signedUrl;
};
