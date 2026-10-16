import type { KennelStatus } from "./kennels";
import type { StayStatus } from "./stays";

// ---------------------------------------------------------------- calendar
/** The nights one pet holds a kennel, as the calendar draws them: [from, to) in yyyy-MM-dd. */
export type TimelineSegment = {
  stayId: string;
  stayCode: string;
  stayStatus: StayStatus;
  stayPetId: string;
  petName: string;
  customerName: string;
  from: string;
  to: string;
};

export type TimelineKennel = {
  id: string;
  code: string;
  name: string | null;
  kennelTypeId: string;
  kennelTypeName: string;
  status: KennelStatus;
  segments: TimelineSegment[];
};

export type BoardingTimeline = { from: string; days: number; kennels: TimelineKennel[] };
