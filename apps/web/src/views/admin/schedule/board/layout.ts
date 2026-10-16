import type { BoardTicket } from "@bongcun/supabase/spa";
import { minutesOfTime, timeOf } from "../format";

/** Pixels per slot of the day grid. */
export const SLOT_PX = 28;

export type PlacedTicket = {
  ticket: BoardTicket;
  top: number;
  height: number;
  /** Side-by-side position when tickets of one column overlap (only unassigned ones can). */
  lane: number;
  lanes: number;
};

const MIN_HEIGHT_PX = SLOT_PX;

/** Places the tickets of one column on the grid: vertical by time, side by side when they overlap. */
export const placeTickets = (tickets: BoardTicket[], openTime: string, slotMinutes: number): PlacedTicket[] => {
  const openAt = minutesOfTime(openTime);
  const sorted = [...tickets].sort((a, b) => a.startAt.localeCompare(b.startAt));
  const laneEnds: number[] = [];
  const placed = sorted.map((ticket) => {
    const start = minutesOfTime(timeOf(ticket.startAt));
    const end = Math.max(start + slotMinutes, minutesOfTime(timeOf(ticket.endAt)));
    let lane = laneEnds.findIndex((laneEnd) => laneEnd <= start);
    if (lane === -1) lane = laneEnds.length;
    laneEnds[lane] = end;
    return {
      ticket,
      top: Math.max(0, ((start - openAt) / slotMinutes) * SLOT_PX),
      height: Math.max(MIN_HEIGHT_PX, ((end - start) / slotMinutes) * SLOT_PX),
      lane,
      lanes: 1,
    };
  });
  const lanes = Math.max(1, laneEnds.length);
  return placed.map((item) => ({ ...item, lanes }));
};
