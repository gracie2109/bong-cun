// Readers for the loosely typed JSON the spa RPCs return.
export const str = (value: unknown): string => (typeof value === "string" ? value : "");
export const strOrNull = (value: unknown): string | null => (typeof value === "string" ? value : null);
export const numOrNull = (value: unknown): number | null => (value === null || value === undefined ? null : Number(value));

export const asRecord = (value: unknown): Record<string, unknown> => (value ?? {}) as Record<string, unknown>;
