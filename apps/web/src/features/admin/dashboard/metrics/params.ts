import type { MetricDef, MetricParams } from "./types";

/**
 * The parameters a widget may use for a metric: each one the metric declares, taken from the saved
 * value when it is allowed and from the metric's default (the first allowed value) otherwise.
 * Returns null when a saved value is not allowed: the widget then shows "no longer available".
 */
export const resolveParams = (def: MetricDef, saved: Record<string, unknown> | undefined): MetricParams | null => {
  const resolved: MetricParams = {};
  for (const [name, allowed] of Object.entries(def.params ?? {})) {
    const value = saved?.[name];
    if (value === undefined) {
      resolved[name] = allowed[0] as string | number;
    } else if (allowed.includes(value as string | number)) {
      resolved[name] = value as string | number;
    } else {
      return null;
    }
  }
  return resolved;
};
