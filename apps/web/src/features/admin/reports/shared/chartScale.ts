// Scale and bar geometry of the stacked bar chart. Pure functions, no Vue.

export const TARGET_TICKS = 4;

export type ChartSeries = { key: string; label: string; color: string };

/** One bar: `values` follow the order of the series, stacked bottom to top. */
export type ChartPoint = { key: string; label: string; title: string; values: number[] };

/** A round number at or above the value: 1, 2, 2.5, 5 or 10 times a power of ten. */
export const niceMax = (value: number): number => {
  if (value <= 0) return 1;
  const power = 10 ** Math.floor(Math.log10(value));
  const fraction = value / power;
  const step = [1, 2, 2.5, 5, 10].find((candidate) => fraction <= candidate) ?? 10;
  return step * power;
};

/** Evenly spaced axis values from 0 up to the nice maximum. */
export const axisTicks = (max: number, count = TARGET_TICKS): number[] =>
  Array.from({ length: count + 1 }, (_, index) => (max / count) * index);

export type StackSegment = { y: number; height: number };

export type Bar = { x: number; width: number; segments: StackSegment[]; top: number };

type BarInput = { values: number[]; index: number; max: number; plotHeight: number; slot: number; gap: number };

/** One bar: each value stacks on the one before it, from the bottom of the plot upward. */
export const barGeometry = ({ values, index, max, plotHeight, slot, gap }: BarInput): Bar => {
  const width = Math.max(slot - gap, 1);
  let filled = 0;
  const segments = values.map((value) => {
    const height = max > 0 ? (Math.max(value, 0) / max) * plotHeight : 0;
    filled += height;
    return { y: plotHeight - filled, height };
  });
  return { x: index * slot + gap / 2, width, segments, top: plotHeight - filled };
};

/** One dot of the line chart. */
export type LinePoint = { key: string; label: string; title: string; value: number };

export type LineDot = { x: number; y: number };

type LineInput = { values: number[]; max: number; plotHeight: number; slot: number };

/** One dot per value, centred in its slot; the first value sits left, the highest value nearest the top. */
export const lineDots = ({ values, max, plotHeight, slot }: LineInput): LineDot[] =>
  values.map((value, index) => ({
    x: index * slot + slot / 2,
    y: max > 0 ? plotHeight - (Math.max(value, 0) / max) * plotHeight : plotHeight,
  }));

const fixed = (value: number): string => String(Math.round(value * 10) / 10);

/** SVG path through the dots ("" for none); a single dot gives a zero-length segment so it still draws. */
export const linePath = (dots: LineDot[]): string =>
  dots.map((dot, index) => `${index === 0 ? "M" : "L"}${fixed(dot.x)} ${fixed(dot.y)}`).join(" ") +
  (dots.length === 1 ? " h0" : "");

/** The same path closed down to the baseline, to fill the area under the line. */
export const areaPath = (dots: LineDot[], plotHeight: number): string => {
  const first = dots[0];
  const last = dots[dots.length - 1];
  return first && last && dots.length > 1
    ? `${linePath(dots)} L${fixed(last.x)} ${fixed(plotHeight)} L${fixed(first.x)} ${fixed(plotHeight)} Z`
    : "";
};
