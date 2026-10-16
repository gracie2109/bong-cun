import type { KennelStatus } from "./kennels";
import type { KennelPurpose } from "./kennels";
import type { StayKind, StayStatus } from "./stays";

// ------------------------------------------------------------------ board
export type KennelState = "free" | "arriving" | "occupied" | "departing" | "overdue" | "cleaning" | "maintenance";

export type BoardPet = {
  stayId: string;
  stayCode: string;
  stayStatus: StayStatus;
  stayPetId: string;
  petId: string;
  petName: string;
  customerName: string;
  plannedInAt: string;
  plannedOutAt: string;
  hasNotes: boolean;
  overdue: boolean;
  /** `inpatient` for a pet admitted from a medical visit, `boarding` for a hotel guest. */
  kind: StayKind;
  visitId: string | null;
  visitCode: string | null;
};

export type BoardKennel = {
  id: string;
  code: string;
  name: string | null;
  kennelTypeId: string;
  kennelTypeName: string;
  /** Medical and isolation kennels are for inpatients; a free one is not bookable as a hotel room. */
  purpose: KennelPurpose;
  status: KennelStatus;
  state: KennelState;
  /** A pet is overdue in a kennel that has a booked arrival: someone has to move. */
  conflict: boolean;
  pets: BoardPet[];
  arriving: BoardPet[];
};

export type BoardCounts = { arriving: number; departing: number; occupied: number; overdue: number; free: number; inpatient: number };

export type DayBoard = { date: string; counts: BoardCounts; kennels: BoardKennel[] };
