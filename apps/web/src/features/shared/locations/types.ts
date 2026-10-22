// Types of the two-level location picker.
import type { LocationRef } from "@bongcun/core/locations";

/** One choice in a combobox. `hint` tells apart two communes of a province that share a name. */
export type PickerOption = { value: string; label: string; hint?: string };

/** What the picker holds while the shopper is choosing: a ward is only valid under its province. */
export type PickerState = { province: LocationRef | null; ward: LocationRef | null };
