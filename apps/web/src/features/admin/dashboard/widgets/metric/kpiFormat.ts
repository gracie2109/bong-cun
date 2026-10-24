import { delta, type Delta } from "@/features/admin/reports";
import type { MetricFormat } from "../../metrics/types";

/** The figure as the screen shows it: money through the shared formatter, counts with thousands separators. */
export const formatFigure = (value: number, format: MetricFormat, money: (value: number) => string): string =>
  format === "money" ? money(value) : value.toLocaleString("vi-VN");

/** The change against the period before; null when there is nothing to compare with. */
export const changeOf = (value: number, previous: number | undefined): Delta | null =>
  previous === undefined ? null : delta(value, previous);

/** Tone of a change: a rise is good unless the metric is one where rising is bad (refunds, overdue). */
export const changeTone = (direction: Delta["direction"], riseIsBad: boolean | undefined): "good" | "bad" | "flat" => {
  if (direction === "flat") return "flat";
  return (direction === "up") !== !!riseIsBad ? "good" : "bad";
};
