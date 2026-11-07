// What the publishing screens work with (camelCase). The database rows live in contract/publish.ts.
import type { RegistrationState } from "./contract/publish";

export type WeekStatus = {
  requirePublish: boolean;
  status: "draft" | "published";
  publishedAt: string | null;
  publishedByName: string | null;
  autoPublished: boolean;
  /** Managers only. */
  pendingRequests: number | null;
  missingCount: number | null;
};

export type RegistrationStatusRow = {
  userId: string;
  name: string;
  mustRegister: boolean;
  state: RegistrationState;
  requestCount: number;
  assignedCount: number;
};

export type RegistrationStatus = { rows: RegistrationStatusRow[]; missingCount: number; closesAt: string | null };

export type Exemption = { userId: string; name: string; note: string | null };
export type WeekWithShifts = { weekMonday: string; shifts: number };
