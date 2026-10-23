import { businessDateOf } from "@/lib/businessDate";
import type { DayBoard } from "@bongcun/core/boarding";

export type PetCounts = { arriving: number; departing: number; occupied: number; overdue: number };

/** The same four numbers as the board counts, but per pet: a big kennel with three pets counts three. */
export const petCounts = (board: Pick<DayBoard, "date" | "kennels">): PetCounts => {
  const counts: PetCounts = { arriving: 0, departing: 0, occupied: 0, overdue: 0 };
  for (const kennel of board.kennels) {
    counts.arriving += kennel.arriving.length;
    for (const pet of kennel.pets) {
      counts.occupied += 1;
      if (pet.overdue) counts.overdue += 1;
      else if (businessDateOf(pet.plannedOutAt) === board.date) counts.departing += 1;
    }
  }
  return counts;
};
