import type { BoardTicket } from "@bongcun/supabase/spa";

export type SpaCounts = { waiting: number; inProgress: number; done: number; cancelled: number };

/** Counts the tickets of the day by status. Only counts what the board already returned. */
export const countTickets = (tickets: readonly BoardTicket[]): SpaCounts => {
  const counts: SpaCounts = { waiting: 0, inProgress: 0, done: 0, cancelled: 0 };
  for (const ticket of tickets) {
    if (ticket.status === "waiting") counts.waiting += 1;
    else if (ticket.status === "in_progress") counts.inProgress += 1;
    else if (ticket.status === "done") counts.done += 1;
    else counts.cancelled += 1;
  }
  return counts;
};

/** The next tickets still to be done, earliest first. */
export const upcomingTickets = (tickets: readonly BoardTicket[], nowIso: string, limit = 3): BoardTicket[] =>
  tickets
    .filter((ticket) => (ticket.status === "waiting" || ticket.status === "in_progress") && ticket.startAt >= nowIso)
    .sort((a, b) => a.startAt.localeCompare(b.startAt))
    .slice(0, limit);
