import type { TimelineSegment } from "@/types/boarding";
import { addDays } from "../format";

/** Width of the kennel column, shared by the header and the rows. */
export const LABEL_WIDTH = "7rem";

export type PlacedSegment = {
  segment: TimelineSegment;
  /** 1-based grid columns, end exclusive. */
  start: number;
  end: number;
  /** 1-based grid row (a lane), for pets that share a kennel on the same nights. */
  lane: number;
  cutLeft: boolean;
  cutRight: boolean;
};

const dayIndex = (from: string, day: string): number =>
  Math.round((Date.parse(`${day}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86_400_000);

/** Clips each segment to the window and stacks overlapping ones in lanes. */
export const placeSegments = (segments: TimelineSegment[], from: string, days: number): PlacedSegment[] => {
  const laneEnds: number[] = [];
  const placed: PlacedSegment[] = [];
  for (const segment of [...segments].sort((a, b) => a.from.localeCompare(b.from))) {
    const rawStart = dayIndex(from, segment.from);
    const rawEnd = dayIndex(from, segment.to);
    const start = Math.max(rawStart, 0);
    const end = Math.min(rawEnd, days);
    if (end <= start) continue;
    let lane = laneEnds.findIndex((laneEnd) => laneEnd <= start);
    if (lane === -1) lane = laneEnds.length;
    laneEnds[lane] = end;
    placed.push({ segment, start: start + 1, end: end + 1, lane: lane + 1, cutLeft: rawStart < 0, cutRight: rawEnd > days });
  }
  return placed;
};

export const laneCount = (placed: PlacedSegment[]): number => Math.max(1, ...placed.map((item) => item.lane));

/** The yyyy-MM-dd of every column. */
export const windowDays = (from: string, days: number): string[] => Array.from({ length: days }, (_, index) => addDays(from, index));
